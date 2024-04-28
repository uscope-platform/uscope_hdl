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
    input wire reset,
    input wire [3:0] main_clock_selector,
    input wire [3:0] comparator_clock_selector,
    output wire main_sampling_clock,
    output wire comparator_sampling_clock,
    output wire sd_clock
);


    // MODULATOR CLOCK GENERATION

    reg mod_clk;
    reg [4:0] modulator_clkgen = 0;
    reg clock_out_inner = 0;

    always_ff @(posedge clock) begin
        mod_clk <= 0;
        if(modulator_clkgen==1)begin
            modulator_clkgen <= 0;
            mod_clk <= 1;
        end else begin
            modulator_clkgen <= modulator_clkgen+1;
        end
    end
    
    always_ff @(posedge clock)begin
        if(mod_clk) clock_out_inner <= ~clock_out_inner;
    end

    assign sd_clock = clock_out_inner;

    // SAMPLING CLOCKS GENERATION

    reg [7:0] sampling_ctr = 0;
    wire main_sampling_clk;

    reg clock_out_inner_del;

    always@(posedge clock) begin
        clock_out_inner_del <= clock_out_inner;
        if(clock_out_inner & ~clock_out_inner_del) sampling_ctr <= sampling_ctr + 1;
    end

    assign main_sampling_clock =  sampling_ctr[main_clock_selector];
   
    wire comparator_sampling_clk;
    assign comparator_sampling_clock =  sampling_ctr[comparator_clock_selector];


endmodule