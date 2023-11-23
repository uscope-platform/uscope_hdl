
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
    axi_stream.master ramp_out,
    axi_lite.slave axil
);


    localparam ADDITIONAL_BITS = 32 - OUTPUT_WIDTH;
    localparam N_REGISTERS = 4;


    wire trigger_axis_write;
    reg [31:0] cu_write_registers [N_REGISTERS-1:0];
    reg [31:0] cu_read_registers [N_REGISTERS-1:0];


    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_REGISTERS),
        .N_WRITE_REGISTERS(N_REGISTERS),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hf),
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
    reg [OUTPUT_WIDTH-1:0] ramp_tb_divisor;

    assign stop_value = cu_write_registers[0];
    assign constant_dest = cu_write_registers[1];
    assign ramp_increment = cu_write_registers[2];
    assign ramp_tb_divisor = cu_write_registers[3];

    assign cu_read_registers[0] = {{ADDITIONAL_BITS{1'b0}}, stop_value};
    assign cu_read_registers[1] = {{ADDITIONAL_BITS{1'b0}}, constant_dest};
    assign cu_read_registers[2] = {{ADDITIONAL_BITS{1'b0}}, ramp_increment};
    assign cu_read_registers[3] = {{ADDITIONAL_BITS{1'b0}}, ramp_tb_divisor};

    
    wire div_tb, timebase;
    assign timebase = ramp_tb_divisor<2 ? clock: div_tb;

    enable_generator_core #(
        .COUNTER_WIDTH(16)
    )tb_gen(
        .clock(clock),
        .reset(reset),
        .gen_enable_in(1),
        .period(ramp_tb_divisor),
        .enable_out(div_tb)
    );

    wire ramp_direction;
    assign ramp_direction = prev_stop_value < shadow_stop_value;

    wire stop_condition; 
    assign stop_condition = ramp_direction ? const_in_progress >= shadow_stop_value :const_in_progress <= shadow_stop_value;

    reg ramp_in_progress = 0;
    reg[OUTPUT_WIDTH-1:0] prev_stop_value = 0;
    reg[OUTPUT_WIDTH-1:0] shadow_stop_value = 0;

    reg [OUTPUT_WIDTH-1:0] const_in_progress;

    always_ff @(posedge clock) begin
        if (~reset) begin
            ramp_out.valid <= 0;
            ramp_out.data <= 0;
            ramp_out.dest <= 0;
        end else begin
            ramp_out.valid <= 0;
            if(trigger_axis_write)begin
                if(prev_stop_value != stop_value)begin
                    ramp_in_progress <= 1;
                    shadow_stop_value<= stop_value;
                    const_in_progress <= prev_stop_value;
                end
            end
            if(timebase & ramp_in_progress)begin
                if(ramp_out.ready) begin
                    if(stop_condition)begin
                        ramp_out.data <= shadow_stop_value;
                    end else begin
                        ramp_out.data <= const_in_progress;
                    end
                    
                    ramp_out.dest <= constant_dest;
                    ramp_out.valid <= 1;
                    if(ramp_direction) begin
                        const_in_progress <= const_in_progress + ramp_increment;
                    end else begin
                        const_in_progress <= const_in_progress - ramp_increment;
                    end
                    
                end 

                if(stop_condition) begin
                    ramp_in_progress <= 0;
                    prev_stop_value <= shadow_stop_value;
                end
            end
        end
    end



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
                "name": "tb_div",
                "offset": "0xC",
                "description": "Divisor used to derive the ramp increment timebase from the clock",
                "direction": "RW"
                
            }
        ]
    }  
    **/
