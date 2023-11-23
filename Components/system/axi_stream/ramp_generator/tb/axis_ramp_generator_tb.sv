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
`include "axi_lite_BFM.svh"						

module axis_ramp_generator_tb();

    reg  clk, reset;

    axi_lite axil();
    axi_lite_BFM axil_bfm;
    
    axi_stream out();
    
    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 


    axis_ramp_generator #( 
        .OUTPUT_WIDTH(16)
    ) UUT(
        .clock(clk),
        .reset(reset),
        .ramp_out(out),
        .axil(axil)
    );


    initial begin
        out.ready = 1;
        axil_bfm = new(axil, 1);
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;


        #1 axil_bfm.write('h43c00004, 'h44);
        #1 axil_bfm.write('h43c00008, 'h2);
        #1 axil_bfm.write('h43c0000C, 'h2);
        #1 axil_bfm.write('h43c00000, 1001);

        #1500;

        #1 axil_bfm.write('h43c00004, 'h22);
        #1 axil_bfm.write('h43c00008, 'h1);
        #1 axil_bfm.write('h43c0000C, 'h0);
        #1 axil_bfm.write('h43c00000, 2000);

        #1200;


        #1 axil_bfm.write('h43c00004, 'h22);
        #1 axil_bfm.write('h43c00008, 'h1);
        #1 axil_bfm.write('h43c0000C, 'h3);
        #1 axil_bfm.write('h43c00000, 200);

    end

endmodule