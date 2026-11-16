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

module enable_generator #(
    COUNTER_WIDTH = 32,
    EXTERNAL_TIMEBASE_ENABLE = 0
)(
    input wire        clock,
    input wire        ext_timebase,
    input wire        reset,
    input wire        gen_enable_in,
    output wire        enable_out,
    axi_lite.slave axil
);

    wire [COUNTER_WIDTH-1:0] count;


    typedef struct {
        reg [30:0] rsvd_1; reg bus_enable;
        reg [31:0] period;
        reg [31:0] enable_threshold;
        
    } enable_generator_registers;
    
    enable_generator_registers registers;

    axil_simple_register_cu #(
        .READ_TYPE(enable_generator_registers),
        .WRITE_TYPE(enable_generator_registers),
        .ADDRESS_MASK('hff)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(registers),
        .output_registers(registers),
        .axil(axil)
    );
    
    wire comparator_out;
    reg synchronized_tb,prev_comp_out;
    
    generate
        if(EXTERNAL_TIMEBASE_ENABLE==1)begin
            assign enable_out = synchronized_tb;
        end else begin
            assign enable_out = comparator_out;
        end
    endgenerate


    always_ff@(posedge clock) begin
        if(registers.period == 0 || registers.period == 1) begin
            synchronized_tb <= ext_timebase;
        end else begin
            prev_comp_out <= comparator_out;
            if(comparator_out & ~prev_comp_out)begin
                synchronized_tb<= 1;
            end else begin
                synchronized_tb<= 0;
            end
        end
    end
    
    enable_generator_counter #(
        .COUNTER_WIDTH(COUNTER_WIDTH),
        .EXTERNAL_TIMEBASE_ENABLE(EXTERNAL_TIMEBASE_ENABLE)
    ) counter(
        .clock(clock),
        .reset(reset),
        .pause(0),
        .external_timebase(ext_timebase),
        .gen_enable_in(registers.bus_enable | gen_enable_in),
        .period(registers.period),
        .counter_out(count)
    );

    enable_comparator #(
        .COUNTER_WIDTH(COUNTER_WIDTH),
        .CLOCK_MODE("FALSE")
    ) comparator_1(
        .clock(clock),
        .reset(reset),
        .enable_treshold(registers.enable_threshold),
        .count(count),
        .enable_out(comparator_out)
    );

endmodule



    /**
       {
        "name": "enable_generator",
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
                "name": "treshold",
                "n_regs": ["1"],
                "description": "value of the counter at which the enable pulse is produced",
                "direction": "RW",
                "fields":[]
                
            }
        ]
    }  
    **/