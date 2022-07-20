// Copyright 2021 Filippo Savi
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

`timescale 10ns / 1ns
`include "interfaces.svh"
`include "axis_BFM.svh"

module merge_sorter_tb ();

    reg clock, reset, start;
    reg [31:0] data_length = 30;

    axi_stream #(.DATA_WIDTH(16)) sorter_in();
    axi_stream sorter_out();

    axis_BFM#(16, 32, 32) in_bfm;
    
    merge_sorter #(
        .DATA_WIDTH(16),
        .MAX_SORT_LENGTH(32)
    )UUT(
        .clock(clock),
        .reset(reset),
        .start(start),
        .data_length(data_length),
        .input_data(sorter_in),
        .output_data(sorter_out)
    );

    initial clock = 0;
    always #0.5 clock = ~clock;

    initial begin
        reset = 1;
        in_bfm = new(sorter_in, 1);
        #10.5 reset = 0;
        #3 reset = 1;

        forever begin
            in_bfm.write($random());
        end
    end

    initial begin
        start = 0;
        #15.5 start = 1;
        #1 start = 0;
    end


endmodule