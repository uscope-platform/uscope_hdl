
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


module axis_ramp_generator #( 
    parameter OUTPUT_WIDTH = 16
) (
    input wire        clock,
    input wire        reset,
    input wire sync,
    axi_stream.master ramp_out,
    axi_lite.slave axil
);


    wire trigger_axis_write;

    typedef struct {
        reg [31:0] stop_value;
        reg [31:0] constant_dest;
        reg [31:0] ramp_increment;
        reg [31:0] ramp_bypass;
    } axis_ramp_generator_registers;

    axis_ramp_generator_registers registers;


    axil_simple_register_cu #(
        .READ_TYPE(axis_ramp_generator_registers),
        .WRITE_TYPE(axis_ramp_generator_registers),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hff),
        .TRIGGER_MASK('{stop_value:1, default:0})
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(registers),
        .output_registers(registers),
        .trigger_out(trigger_axis_write),
        .axil(axil)
    );

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

    assign inner_ramp.dest = registers.constant_dest;

    always_ff @(posedge clock) begin

        inner_ramp.valid <= 0;
        case(ramp_generator_state)
        rg_idle:begin
            if(trigger_axis_write & ~registers.ramp_bypass)begin
                shadow_stop_value<= registers.stop_value;
                ramp_generator_state <= rg_in_progress;
                const_in_progress <= prev_stop_value;
            end else if(trigger_axis_write && registers.ramp_bypass) begin
                inner_ramp.data  <= registers.stop_value;
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
                    const_in_progress <= const_in_progress + registers.ramp_increment;
                end else begin
                    const_in_progress <= const_in_progress - registers.ramp_increment;
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
                    const_in_progress <= const_in_progress + registers.ramp_increment;
                end else begin
                    const_in_progress <= const_in_progress - registers.ramp_increment;
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
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "stop_value",
                "n_regs": ["1"],
                "description": "Value at which the ramp will end",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "dest",
                "n_regs": ["1"],
                "description": "Value of the AXI stream dest signal associated with the constant",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "inc",
                "n_regs": ["1"],
                "description": "Value of the increment for each ramp step",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "ramp_bypass",
                "n_regs": ["1"],
                "description": "A write an output bypassing the ramp (for initialization and debug purposes)",
                "direction": "RW",
                "fields":[]
                
            }
        ]
    }  
    **/
