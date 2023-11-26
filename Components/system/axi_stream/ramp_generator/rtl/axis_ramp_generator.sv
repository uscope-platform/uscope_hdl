
// Copyright 2021 University of Nottingham Ningbo China
// Author: Filippo Savi <filssavi@gmail.com>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`timescale 10 ns / 1 ns
`include "interfaces.svh"


module axis_ramp_generator #( 
    parameter OUTPUT_WIDTH = 16
) (
    input wire        clock,
    input wire        reset,
    input wire sync,
    axi_stream.master ramp_out,
    axi_lite.slave axil
);


    localparam ADDITIONAL_BITS = 32 - OUTPUT_WIDTH;
    localparam N_REGISTERS = 4;


    wire trigger_axis_write;
    wire ramp_bypass;
    reg [31:0] cu_write_registers [N_REGISTERS-1:0];
    reg [31:0] cu_read_registers [N_REGISTERS-1:0];


    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_REGISTERS),
        .N_WRITE_REGISTERS(N_REGISTERS),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('h1f),
        .N_TRIGGER_REGISTERS(1),
        .TRIGGER_REGISTERS_IDX({0})
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .trigger_out(trigger_axis_write),
        .axil(axil)
    );


    reg [OUTPUT_WIDTH-1:0] stop_value;
    reg [31:0] constant_dest;
    reg [OUTPUT_WIDTH-1:0] ramp_increment;

    assign stop_value = cu_write_registers[0];
    assign constant_dest = cu_write_registers[1];
    assign ramp_increment = cu_write_registers[2];
    assign ramp_bypass = cu_write_registers[3][0];

    assign cu_read_registers[0] = {{ADDITIONAL_BITS{1'b0}}, stop_value};
    assign cu_read_registers[1] = {{ADDITIONAL_BITS{1'b0}}, constant_dest};
    assign cu_read_registers[2] = {{ADDITIONAL_BITS{1'b0}}, ramp_increment};
    assign cu_read_registers[3] = ramp_bypass;

    reg [OUTPUT_WIDTH-1:0] const_in_progress = 0;


    wire ramp_direction;
    assign ramp_direction = prev_stop_value < shadow_stop_value;

    wire stop_condition; 
    assign stop_condition = ramp_direction ? const_in_progress >= shadow_stop_value : const_in_progress <= shadow_stop_value;

    reg[OUTPUT_WIDTH-1:0] prev_stop_value = 0;
    reg[OUTPUT_WIDTH-1:0] shadow_stop_value = 0;

    axi_stream inner_ramp();


    wire [15:0] selected_data;
    assign selected_data = stop_condition ? shadow_stop_value: const_in_progress; 
    

    enum logic [1:0]  { 
        rg_idle = 0,
        rg_in_progress = 1,
        rg_wait_sync = 2
    } ramp_generator_state = rg_idle;

    assign inner_ramp.dest = constant_dest;

    always_ff @(posedge clock) begin

        inner_ramp.valid <= 0;
        case(ramp_generator_state)
        rg_idle:begin
            if(trigger_axis_write & ~ramp_bypass)begin
                shadow_stop_value<= stop_value;
                ramp_generator_state <= rg_in_progress;
                const_in_progress <= prev_stop_value;
            end else if(trigger_axis_write && ramp_bypass) begin
                inner_ramp.data  <= stop_value;
                inner_ramp.valid <= 1;
            end
        end
        rg_in_progress:begin
            if(sync & inner_ramp.ready)begin

                inner_ramp.data <= selected_data;
                inner_ramp.valid <= 1;
                
                if(stop_condition) begin
                    ramp_generator_state <= rg_idle;
                    prev_stop_value <= shadow_stop_value;
                end 
                if(ramp_direction)begin
                    const_in_progress <= const_in_progress + ramp_increment;
                end else begin
                    const_in_progress <= const_in_progress - ramp_increment;
                end
            end else begin
                ramp_generator_state <= rg_wait_sync;
            end
        end
        rg_wait_sync:begin
            if(sync & inner_ramp.ready) begin

                inner_ramp.data <= selected_data;
                inner_ramp.valid <= 1;

                if(stop_condition) begin
                    ramp_generator_state <= rg_idle;
                    prev_stop_value <= shadow_stop_value;
                end else begin
                    ramp_generator_state <= rg_in_progress;
                end

                if(ramp_direction)begin
                    const_in_progress <= const_in_progress + ramp_increment;
                end else begin
                    const_in_progress <= const_in_progress - ramp_increment;
                end

            end
        end
        endcase
    end


    axis_skid_buffer #(
        .REGISTER_OUTPUT(0)
    ) skid_b(
        .clock(clock),
        .reset(reset),
        .axis_in(inner_ramp),
        .axis_out(ramp_out)
    );


endmodule


    /**
       {
        "name": "axis_ramp_Generator",
        "type": "peripheral",
        "registers":[
            {
                "name": "stop_value",
                "offset": "0x0",
                "description": "Value at which the ramp will end",
                "direction": "RW"
            },
            {
                "name": "dest",
                "offset": "0x4",
                "description": "Value of the AXI stream dest signal associated with the constant",
                "direction": "RW"
            },
            {
                "name": "inc",
                "offset": "0x8",
                "description": "Value of the increment for each ramp step",
                "direction": "RW"
            },
            {
                "name": "ramp_bypass",
                "offset": "0xC",
                "description": "A write an output bypassing the ramp (for initialization and debug purposes)",
                "direction": "RW"
                
            }
        ]
    }  
    **/
