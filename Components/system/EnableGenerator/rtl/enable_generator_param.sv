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

module enable_generator_param #(
    N_ENABLES = 3,
    COUNTER_WIDTH = 32,
    EXTERNAL_TIMEBASE_ENABLE = 0
)(
    input wire        clock,
    input wire        reset,
    input wire        ext_timebase,
    input wire        gen_enable_in,
    input wire        pause,
    output wire [N_ENABLES-1:0]  enable_out,
    axi_lite.slave axil
);


    typedef struct {
        reg [30:0] rsvd_1; reg bus_enable;
        reg [31:0] period;
        reg [31:0] enable_threshold [N_ENABLES];
    } enable_generator_param_registers;
    
    enable_generator_param_registers registers;


    axil_simple_register_cu #(
        .READ_TYPE(enable_generator_param_registers),
        .WRITE_TYPE(enable_generator_param_registers),
        .ADDRESS_MASK('hff)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(registers),
        .output_registers(registers),
        .axil(axil)
    );


    wire [COUNTER_WIDTH-1:0] count;

    enable_generator_counter #(
        .COUNTER_WIDTH(COUNTER_WIDTH),
        .EXTERNAL_TIMEBASE_ENABLE(EXTERNAL_TIMEBASE_ENABLE)
    ) counter (
        .clock(clock),
        .reset(reset),
        .external_timebase(ext_timebase),
        .gen_enable_in(registers.bus_enable | gen_enable_in),
        .pause(pause),
        .period(registers.period),
        .counter_out(count)
    );

    reg [N_ENABLES-1:0] internal_enable_out;
   
    genvar i;
    generate
        for (i = 0; i < N_ENABLES; i++) begin

            enable_comparator #(
                .COUNTER_WIDTH(COUNTER_WIDTH),
                .CLOCK_MODE("FALSE")
            ) comparator (
                .clock(clock),
                .reset(reset),
                .enable_treshold(registers.enable_threshold[i]),
                .count(count),
                .enable_out(internal_enable_out[i])
            );
            
        end
    endgenerate

    wire [N_ENABLES-1:0] selected_enable;
   
    enable_generator_tb_sync #(
        .N_ENABLES(N_ENABLES),
        .ENABLE(EXTERNAL_TIMEBASE_ENABLE)
    ) tb_sync (
        .clock(clock),
        .bypass(registers.period == 0 || registers.period == 1),
        .ext_timebase(ext_timebase),
        .enable_in(internal_enable_out),
        .enable_out(selected_enable)
    );
    assign enable_out = selected_enable & {N_ENABLES{~pause}};

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
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "period",
                "n_regs": ["1"],
                "description": "Period of the enable pulses in clock cycles",
                "direction": "RW",
                "fields":[]
            },           
            {
                "name": "treshold_$",
                "n_regs": ["MAX_STEPS"],
                "description": "value of the counter at which the enable $ pulse is triggered",
                "direction": "RW",
                "fields":[]
            }
        ]
    }   
 **/