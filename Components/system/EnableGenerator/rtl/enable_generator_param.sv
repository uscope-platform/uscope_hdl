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

module enable_generator_param #(
    N_ENABLES = 3,
    COUNTER_WIDTH = 32
)(
    input wire        clock,
    input wire        reset,
    input wire        gen_enable_in,
    output wire [N_ENABLES-1:0]  enable_out,
    axi_lite.slave axil
);


    reg [COUNTER_WIDTH-1:0] period;
    wire [COUNTER_WIDTH-1:0] count;
    reg bus_enable;
    reg [COUNTER_WIDTH-1:0] enable_threshold [N_ENABLES-1:0];


    localparam N_REGISTERS = 2+N_ENABLES;

    logic [31:0] cu_write_registers [N_REGISTERS-1:0];
    logic [31:0] cu_read_registers [N_REGISTERS-1:0];

    localparam ADDITIONAL_BITS = 32 - COUNTER_WIDTH;

    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_REGISTERS),
        .N_WRITE_REGISTERS(N_REGISTERS),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hFF)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axil)
    );

    assign cu_read_registers = cu_write_registers;

    assign bus_enable = cu_write_registers[0][0];
    assign period = cu_write_registers[1];

    enable_generator_counter #(
        .COUNTER_WIDTH(COUNTER_WIDTH),
        .EXTERNAL_TIMEBASE_ENABLE(0)
    ) counter(
        .clock(clock),
        .reset(reset),
        .gen_enable_in(bus_enable | gen_enable_in),
        .period(period),
        .counter_out(count)
    );



    genvar i;
    generate
        for (i = 0; i < N_ENABLES; i++) begin
            assign enable_threshold[i] = cu_write_registers[i+2];

            enable_comparator #(
                .COUNTER_WIDTH(COUNTER_WIDTH),
                .CLOCK_MODE("FALSE")
            ) comparator(
                .clock(clock),
                .reset(reset),
                .enable_treshold(enable_threshold[i]),
                .count(count),
                .enable_out(enable_out[i])
            );
            
        end
    endgenerate



endmodule

 /**
    {
        "name": "enable_generator_param",
        "alias": "enable_generator_param",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "enable",
                "n_regs": ["1"],
                "description": "Writing 1 to this register enables the generator",
                "direction": "RW"
            },
            {
                "name": "period",
                "n_regs": ["1"],
                "description": "Period of the enable pulses in clock cycles",
                "direction": "RW"
            },           
            {
                "name": "treshold_$",
                "n_regs": ["MAX_STEPS"],
                "description": "value of the counter at which the enable $ pulse is triggered",
                "direction": "RW"
            }
        ]
    }   
 **/