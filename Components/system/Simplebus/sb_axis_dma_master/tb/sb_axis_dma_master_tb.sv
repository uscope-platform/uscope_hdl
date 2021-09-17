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
							
module sb_axis_dma_master_tb();

    reg  clk, reset, enable;
    
    Simplebus sb();
    axi_stream stream();

    defparam UUT.BASE_ADDRESS = 'h43c00000;
    defparam UUT.CHANNEL_OFFSET = 'h2;
    defparam UUT.DESTINATION_OFFSET = 'h2;
    defparam UUT.CHANNEL_NUMBER = 3;
    defparam UUT.SOURCE_CHANNEL_SEQUENCE = {3,2,1};
    defparam UUT.TARGET_CHANNEL_SEQUENCE = {1,2,3};
    sb_axis_dma_master UUT(
        .clock(clk),
        .reset(reset),
        .enable(enable),
        .source(sb),
        .target(stream)
    );
    

    defparam test_rom.BASE_ADDRESS = 'h43c00000;
    simplebus_rom test_rom (
        .clock(clk),
        .reset(reset),
        .sb(sb)
    );


    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 


    initial begin
        stream.ready <= 1;
        reset <=1'h1;
        enable <= 0;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;
                 
        #15 enable <= 1;
        #1 enable <= 0;
        #3 stream.ready <= 0;
        #8 stream.ready <= 1;
    end




endmodule