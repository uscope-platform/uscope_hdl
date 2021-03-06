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
//`include "interfaces.svh"

module pwmChain #(parameter N_CHAINS=2, N_CHANNELS=3, BASE_ADDRESS=32'h43c00004, COUNTER_WIDTH=16)(
    input wire clock,
    input wire reset,
    input wire timebase,
    input wire external_counter_run,
    input wire sync,
    input wire stop_request,
    output wire counter_status,
    output wire [N_CHANNELS-1:0] out_a,
    output wire [N_CHANNELS-1:0] out_b,
    Simplebus.slave sb
    );

    wire counterEnable;
    wire [COUNTER_WIDTH-1:0] counter_out;
    reg [COUNTER_WIDTH-1:0] counter_out_reg;
    wire [N_CHANNELS-1:0] compare_match_high;
    wire [N_CHANNELS-1:0] compare_match_low;
    wire [N_CHANNELS-1:0] pin_out_a;
    wire [N_CHANNELS-1:0] pin_out_b;
    wire reload_compare;


    wire enable_in, compare_write_strobe;
    wire [2:0] counter_mode;
    wire [2:0] compare_address;
    wire [COUNTER_WIDTH-1:0] compare_data_in;
    wire [COUNTER_WIDTH-1:0] counter_start_data;
    wire [COUNTER_WIDTH-1:0] counter_stop_data;
    wire [15:0] timebase_shift;
    wire [1:0] output_enable [N_CHANNELS-1:0];
    wire [15:0] deadtime [N_CHANNELS-1:0];
    wire deadtime_enable[N_CHANNELS-1:0];
    reg  counter_stopped;

    assign counter_status = ~counter_stopped;
    

    always@(posedge clock)begin
        if(~reset)begin
            counter_stopped <= 1;
            counter_out_reg <= 0;
        end else begin
            counter_stopped <= ~counterEnable;
            counter_out_reg <= counter_out;
        end
    end

    defparam ControlUnit.BASE_ADDRESS = BASE_ADDRESS;
    defparam ControlUnit.N_CHANNELS = 3;
    defparam ControlUnit.COUNTER_WIDTH = COUNTER_WIDTH;
    ChainControlUnit ControlUnit(
        .clock(clock),
        .reset(reset),
        .counter_running(~counter_stopped),
        .counter_run(enable_in),
        .timebase_shift(timebase_shift),
        .counter_mode(counter_mode),
        .counter_start_data(counter_start_data),
        .counter_stop_data(counter_stop_data),
        .compare_write_strobe(compare_write_strobe),
        .compare_address(compare_address),
        .compare_data_in(compare_data_in),
        .output_enable_0(output_enable[0]),
		.output_enable_1(output_enable[1]),
		.output_enable_2(output_enable[2]),
        .deadtime_0(deadtime[0]),
        .deadtime_1(deadtime[1]),
		.deadtime_2(deadtime[2]),
        .deadtime_enable_0(deadtime_enable[0]),
		.deadtime_enable_1(deadtime_enable[1]),
		.deadtime_enable_2(deadtime_enable[2]),
        .sb(sb)
    );


 CounterEnableDelay timebase_shifter(
        .clock(clock),
        .reset(reset),
        .enable((enable_in | external_counter_run) & ~stop_request),
        .delay(timebase_shift),
        .delayedEnable(counterEnable)
    );

    defparam counter.COUNTER_WIDTH = COUNTER_WIDTH;
    Counter counter(
        .clock(clock),
        .reset(reset),
        .sync(sync),
        .timebase(timebase),
        .run(counterEnable),   
        .mode(counter_mode),
        .counter_start_data(counter_start_data),
        .counter_stop_data(counter_stop_data),
        .countOut(counter_out),
        .reload_compare(reload_compare)
    );

    defparam compare.COUNTER_WIDTH = COUNTER_WIDTH;
    CompareUnit compare(
        .clock(clock),
        .reset(reset),
        .counter_stopped(counter_stopped),
        .counterValue(counter_out),
        .we(compare_write_strobe),
        .adress(compare_address),
        .dataIn(compare_data_in),
        .reload_compare(reload_compare),
        .matchHigh(compare_match_high),
        .matchLow(compare_match_low)
    );


    genvar i;
    generate for (i = 0; i < N_CHANNELS; i = i + 1) begin : pwm_chain
        //%%PinControl%%
        PinControl pinControl(
            .clock(clock),
            .reset(reset),
            .matchHigh(compare_match_high[i]),
            .matchLow(compare_match_low[i]),
            .enableOutputs(output_enable[i]),
            .counter_stopped(counter_stopped),
            .outA(pin_out_a[i]),
            .outB(pin_out_b[i])
        );
        //%%DeadTimeGenerator%%
        DeadTimeGenerator deadtime(
            .clock(clock),
            .reset(reset),
            .enable(deadtime_enable[i]),
            .deadTime(deadtime[i]),
            .in_a(pin_out_a[i]),
            .in_b(pin_out_b[i]),
            .out_a(out_a[i]),
            .out_b(out_b[i])
        );
        
    end
    endgenerate
    
endmodule