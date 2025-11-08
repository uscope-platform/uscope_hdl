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
`include "axis_BFM.svh"
`include "axi_lite_BFM.svh"						

module multichannel_constant_tb();

    reg  clk, reset;

    axi_lite axil();
    axi_lite_BFM axil_bfm;
    
    axi_stream out();
    
    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 


    reg sync;

    initial begin
        sync = 0;
        #150.5;
        forever begin
            #100 sync <= 1;
            #1 sync <= 0;
        end
    end
    multichannel_constant #(
        .CONSTANT_WIDTH(32),
        .N_CHANNELS(11),
        .N_CONSTANTS(3)
    ) UUT(
        .clock(clk),
        .reset(reset),
        .sync(sync),
        .const_out(out),
        .axil(axil)
    );

    localparam const_low = 'h0;
    localparam const_high = 'h4;
    localparam dest = 'h8;
    localparam selector = 'hc;
    localparam clear = 'h10;
    localparam active_channels = 'h14;

    initial begin
        out.ready = 1;
        axil_bfm = new(axil, 1);
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;

        #10 axil_bfm.write(active_channels, 3);

        //Write constants
        #1 axil_bfm.write(selector,{16'h0,16'h0}); 
        #1 axil_bfm.write(dest, 7);
        #1 axil_bfm.write(const_low, 32'h55); 
        
        #1 axil_bfm.write(selector,{16'h1,16'h0}); 
        #1 axil_bfm.write(dest, 9);
        #1 axil_bfm.write(const_low, 32'h56); 
        
        #1 axil_bfm.write(selector,{16'h2,16'h0}); 
        #1 axil_bfm.write(dest, 1);
        #1 axil_bfm.write(const_low, 32'h57); 
        



        #1 axil_bfm.write(selector,{16'h0,16'h1}); 
        #1 axil_bfm.write(dest, 12);
        #1 axil_bfm.write(const_low, 32'h65); 
        
        #1 axil_bfm.write(selector,{16'h1,16'h1}); 
        #1 axil_bfm.write(dest, 37);
        #1 axil_bfm.write(const_low, 32'h66); 
        
        #1 axil_bfm.write(selector,{16'h2,16'h1}); 
        #1 axil_bfm.write(dest, 2);
        #1 axil_bfm.write(const_low, 32'h67); 




        #1 axil_bfm.write(selector,{16'h0,16'h2}); 
        #1 axil_bfm.write(dest, 4);
        #1 axil_bfm.write(const_low, 32'h75); 
        
        #1 axil_bfm.write(selector,{16'h1,16'h2}); 
        #1 axil_bfm.write(dest, 44);
        #1 axil_bfm.write(const_low, 32'h76); 
        
        #1 axil_bfm.write(selector,{16'h2,16'h2}); 
        #1 axil_bfm.write(dest, 6);
        #1 axil_bfm.write(const_low, 32'h77); 
    end

endmodule