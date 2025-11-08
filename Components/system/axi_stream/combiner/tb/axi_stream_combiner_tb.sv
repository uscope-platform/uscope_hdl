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
`include "axis_BFM.svh"


module axi_stream_combiner_tb();


    reg  clk, reset;
    axi_stream stream_1();
    axi_stream stream_2();
    axi_stream merged_stream();

    axi_stream_combiner #(
        .INPUT_DATA_WIDTH(16),
        .OUTPUT_DATA_WIDTH(32),
        .DEST_WIDTH(8),
        .USER_WIDTH(8),
        .N_STREAMS(2)
    ) UUT (
        .clock(clk),
        .reset(reset),
        .stream_in({stream_1, stream_2}),
        .stream_out(merged_stream)
    );


    //clock generation
    initial clk = 0;
    always #0.5 clk = ~clk;

    axis_BFM BFM_1;
    axis_BFM BFM_2;

    integer i;

    initial begin
        BFM_1 = new(stream_1,1);
        BFM_2 = new(stream_2,1);
        merged_stream.ready <= 1;
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;

        for(i = 0; i< 1050; i++)begin
            #10 BFM_1.write($urandom);
        end
    end


    initial begin

        #6.5;
        for(i = 0; i< 1050; i++)begin
            #10 BFM_2.write($urandom);
        end
    end
endmodule
