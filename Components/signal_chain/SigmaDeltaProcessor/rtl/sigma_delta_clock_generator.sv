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
    input wire ref_clock_in,
    input wire reset,
    input wire [3:0] main_clock_selector,
    input wire [3:0] comparator_clock_selector,
    output wire main_sampling_clock,
    output wire comparator_sampling_clock,
    output wire sd_clock
);

    assign sd_clock = ref_clock_in;
    // SAMPLING CLOCKS GENERATION

    reg [8:0] sampling_ctr = 0;

    reg ref_clock_in_del;

    always@(posedge clock) begin
        ref_clock_in_del <= ref_clock_in;
        if(ref_clock_in & ~ref_clock_in_del) sampling_ctr <= sampling_ctr + 1;
    end

    assign main_sampling_clock =  sampling_ctr[main_clock_selector+1];
    assign comparator_sampling_clock =  sampling_ctr[comparator_clock_selector+1];


endmodule