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
`include "SimpleBus_BFM.svh"
`include "axis_BFM.svh"
							
module axis_limiter_tb();

    reg  clk, reset;
    axi_stream input_stream();
    axi_stream output_stream();
    Simplebus sb();
    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 
    
    
    axis_limiter #(
        .BASE_ADDRESS('h43c00000)
    ) UUT (
        .clock(clk),
        .reset(reset),
        .in(input_stream),
        .out(output_stream),
        .sb(sb)
    );

    simplebus_BFM sb_bfm;
    axis_BFM stream_bfm;

    initial begin
        sb_bfm = new(sb,1);
        stream_bfm = new(input_stream,1);
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;
        input_stream.dest <= 123;
        input_stream.user <= 125;
        output_stream.ready <= 1;
        sb_bfm.write('h43c00000, 100);
        sb_bfm.write('h43c00004, 20);

        #5 stream_bfm.write(1000);
        #5 stream_bfm.write(50);
        #5 stream_bfm.write(4);

        stream_bfm.write($urandom%120);
        stream_bfm.write($urandom%120);
        output_stream.ready <= 0;
        #3 output_stream.ready <= 1;
        stream_bfm.write($urandom%120);
        stream_bfm.write($urandom%120);
    end

endmodule