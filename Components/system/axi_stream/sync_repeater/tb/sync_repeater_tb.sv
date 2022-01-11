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

`timescale 10ns / 1ns
`include "interfaces.svh"
`include "axis_BFM.svh"
							
module axis_sync_repeater_tb();

    reg  clk, reset, sync;
    axi_stream input_stream();
    axi_stream output_stream();
    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 
    
    
     axis_sync_repeater #(
        .SYNC_DELAY(2),
        .DATA_WIDTH(32),
        .DEST_WIDTH(8),
        .USER_WIDTH(8)
     ) UUT (
        .clock(clk),
        .reset(reset),
        .sync(sync),
        .in(input_stream),
        .out(output_stream)
    );

    axis_BFM stream_bfm;

    initial begin
        stream_bfm = new(input_stream,1);
        reset <=1'h1;
        sync <= 0;
        input_stream.dest <= 0;
        input_stream.user <= 0;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;
        output_stream.ready <= 1;
        input_stream.dest <= 123;
        input_stream.user <= 125;
        input_stream.data <= 1000;
        input_stream.valid <= 1;
    end

endmodule