// Copyright 2023 Filippo Savi
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

module sigma_delta_clock_generator (
    input wire clock,
    input wire enable,
    input wire reset,
    input wire [3:0] main_clock_selector,
    input wire [3:0] comparator_clock_selector,
    output wire main_sampling_clock,
    output wire comparator_sampling_clock,
    output wire sd_clock
);

    reg mod_clk;

    reg clk_on_event, clk_off_event;

    reg [2:0] mod_clk_on_ctr = 0;
    reg [2:0] mod_clk_off_ctr = 3;

    always@(posedge clock) begin
        clk_on_event <= 0;
        if(mod_clk_on_ctr == 4) begin
            mod_clk_on_ctr <= 0;
            clk_on_event <= 1;
        end else begin
            mod_clk_on_ctr <= mod_clk_on_ctr + 1;
        end
    end

    always@(negedge clock) begin
        clk_off_event <= 0;
        if(mod_clk_off_ctr == 4) begin
            mod_clk_off_ctr <= 0;
            clk_off_event <= 1;
        end else begin
            mod_clk_off_ctr <= mod_clk_off_ctr + 1;
        end
    end

    always_latch begin
        if(clk_on_event) begin
            mod_clk<= 1;
        end else if(clk_off_event) begin
            mod_clk<= 0;
        end
    end

    assign sd_clock = enable & mod_clk;

    // SAMPLING CLOCKS GENERATION


    reg [8:0] sampling_ctr = 0;

    reg mod_clk_del;

    always@(posedge clock) begin
        if(enable)begin
            mod_clk_del <= mod_clk;
            if(mod_clk & ~mod_clk_del) sampling_ctr <= sampling_ctr + 1;
        end
    end

    assign main_sampling_clock =  sampling_ctr[main_clock_selector+1];
    assign comparator_sampling_clock =  sampling_ctr[comparator_clock_selector+1];


endmodule