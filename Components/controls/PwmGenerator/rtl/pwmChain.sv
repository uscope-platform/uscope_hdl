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

module pwmChain #(
    parameter N_CHAINS=2,
    N_CHANNELS=4,
    HR_ENABLE = "FALSE",
    ENANCING_MODE = "DUTY",
    COUNTER_WIDTH=16,
    PRAGMA_MKFG_MODULE_TOP = "pwmChain"
)(
    input wire clock,
    input wire reset,
    input wire [2:0] high_resolution_clock,
    input wire timebase,
    input wire fast_count,
    input wire external_counter_run,
    input wire sync,
    input wire stop_request,
    output wire counter_status,
    output wire sync_out,
    output wire [N_CHANNELS-1:0] out_a,
    output wire [N_CHANNELS-1:0] out_b,
    axi_lite.slave axi_in
    );

    wire [COUNTER_WIDTH-1:0] counter_out;
    reg [COUNTER_WIDTH-1:0] counter_out_reg;
    wire [N_CHANNELS-1:0] compare_match_high;
    wire [N_CHANNELS-1:0] compare_match_low;
    wire [N_CHANNELS-1:0] pin_out_a;
    wire [N_CHANNELS-1:0] pin_out_b;
    wire [N_CHANNELS-1:0] dt_out_a;
    wire [N_CHANNELS-1:0] dt_out_b;
    wire reload_compare;

    wire [2:0] counter_mode;
    wire [COUNTER_WIDTH-1:0] compare_tresholds [N_CHANNELS*2-1:0];
    wire [COUNTER_WIDTH-1:0] counter_start_data;
    wire [COUNTER_WIDTH-1:0] counter_stop_data;
    wire [COUNTER_WIDTH-1:0] timebase_shift;
    wire [1:0] output_enable [N_CHANNELS-1:0];
    wire [COUNTER_WIDTH-1:0] deadtime [N_CHANNELS-1:0];
    wire deadtime_enable [N_CHANNELS-1:0];
    reg  counter_stopped;

    assign counter_status = ~counter_stopped;
    assign sync_out = reload_compare;

    always@(posedge clock)begin
        if(~reset)begin
            counter_stopped <= 1;
            counter_out_reg <= 0;
        end else begin
            counter_stopped <= ~(external_counter_run & ~stop_request);
            counter_out_reg <= counter_out;
        end
    end

    ChainControlUnit #(
        .N_CHANNELS(N_CHANNELS),
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) ControlUnit(
        .clock(clock),
        .reset(reset),
        .counter_running(~counter_stopped),
        .timebase_shift(timebase_shift),
        .counter_mode(counter_mode),
        .counter_start_data(counter_start_data),
        .counter_stop_data(counter_stop_data),
        .comparator_tresholds(compare_tresholds),
        .output_enable(output_enable),
        .deadtime(deadtime),
        .deadtime_enable(deadtime_enable),
        .axi_in(axi_in)
    );

    Counter #(
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) counter(
        .clock(clock),
        .reset(reset),
        .sync(sync),
        .fast_count(fast_count),
        .shift(timebase_shift),
        .timebase(timebase),
        .run(external_counter_run & ~stop_request),
        .mode(counter_mode),
        .counter_start_data(counter_start_data),
        .counter_stop_data(counter_stop_data),
        .countOut(counter_out),
        .reload_compare(reload_compare)
    );

    CompareUnit #(
        .COUNTER_WIDTH(COUNTER_WIDTH),
        .N_CHANNELS(N_CHANNELS)
    ) compare(
        .clock(clock),
        .reset(reset),
        .counter_stopped(counter_stopped),
        .counterValue(counter_out),
        .comparator_tresholds(compare_tresholds),
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
        DeadTimeGenerator deadtime_gen(
            .clock(clock),
            .reset(reset),
            .enable(deadtime_enable[i]),
            .deadTime(deadtime[i]),
            .in_a(pin_out_a[i]),
            .in_b(pin_out_b[i]),
            .out_a(dt_out_a[i]),
            .out_b(dt_out_b[i])
        );

        ResolutionEnhancer #(
            .ENABLE(HR_ENABLE),
            .ENANCING_MODE(ENANCING_MODE)
        ) res_enhancer_a(
            .clock(clock),
            .high_resolution_clock(high_resolution_clock),
            .reset(reset),
            .in(dt_out_a[i]),
            .count(timebase_shift[2:0]),
            .out(out_a[i])
        );

        ResolutionEnhancer #(
            .ENABLE(HR_ENABLE),
            .ENANCING_MODE(ENANCING_MODE)
        ) res_enhancer_b(
            .clock(clock),
            .high_resolution_clock(high_resolution_clock),
            .reset(reset),
            .in(dt_out_b[i]),
            .count(timebase_shift[2:0]),
            .out(out_b[i])
        );
    end
    endgenerate

endmodule
