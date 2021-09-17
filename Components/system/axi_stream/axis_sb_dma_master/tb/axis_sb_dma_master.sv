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
							
module axis_sb_dma_master_tb();

    reg  clk, reset;
    
    Simplebus sb();
    axi_stream stream();

    defparam UUT.BASE_ADDRESS = 'h43c00000;
    defparam UUT.CHANNEL_OFFSET = 'h20;
    defparam UUT.DESTINATION_OFFSET = 'h4;
    defparam UUT.CHANNEL_NUMBER = 3;
    defparam UUT.CHANNEL_SEQUENCE = {3,2,1};
    axis_sb_dma_master UUT(
        .clock(clk),
        .reset(reset),
        .stream(stream),
        .sb(sb)
    );


    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 

    axis_BFM axis_BFM;

    initial begin
        axis_BFM = new(stream,1);
        sb.sb_ready <= 1;
        stream.user <= 0;
        sb.sb_read_data <= 0;
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;

        for(integer i = 0; i<3; i++)begin
            #5 stream.dest <= 0;
            axis_BFM.write($urandom);
        end 
        for(integer i = 0; i<3; i++)begin
            #5 stream.dest <= 1;
            axis_BFM.write($urandom);
        end 
        for(integer i = 0; i<3; i++)begin
            #5 stream.dest <= 2;
            axis_BFM.write($urandom);
        end 
               
         #15 stream.dest <= 3;
         stream.user <= 1;
         axis_BFM.write($urandom);
                 
    end




endmodule