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
`timescale 10 ns / 1 ns
`include "axi_lite_BFM.svh"
`include "interfaces.svh"


module fir_filter_tb();

    reg  clk, reset;

    event config_done;
    
    axi_lite cfg_axi();
    axi_lite_BFM axil_bfm;


    axi_stream #(
        .DATA_WIDTH(16)
    ) filter_in();

    axi_stream #(
        .DATA_WIDTH(16)
    ) filter_out();

    fir_filter #(
        .MAX_FOLDING_FACTOR(1),
        .PARALLEL_ORDER(101),
        .TAPS_IV('{5, 10, 19, 32, 48, 67, 87, 108, 126, 138, 142, 135, 114, 80, 32, -26, -90, -153, -209, -250, -270, -262, -225, -160, -71, 33, 140, 237, 309, 342, 327, 259, 139, -25, -218, -417, -597, -730, -789, -751, -600, -330, 53, 535, 1088, 1676, 2258, 2790, 3232, 3549, 3714, 3714, 3549, 3232, 2790, 2258, 1676, 1088, 535, 53, -330, -600, -751, -789, -730, -597, -417, -218, -25, 139, 259, 327, 342, 309, 237, 140, 33, -71, -160, -225, -262, -270, -250, -209, -153, -90, -26, 32, 80, 114, 135, 142, 138, 126, 108, 87, 67, 48, 32, 19, 10, 5})
    )UUT(
        .clock(clk),
        .reset(reset),
        .cfg_in(cfg_axi),
        .data_in(filter_in),
        .data_out(filter_out)
    );



    always begin
        clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5;
    end

    reg signed [15:0] taps [101:0] = '{5, 10, 19, 32, 48, 67, 87, 108, 126, 138, 142, 135, 114, 80, 32, -26, -90, -153, -209, -250, -270, -262, -225, -160, -71, 33, 140, 237, 309, 342, 327, 259, 139, -25, -218, -417, -597, -730, -789, -751, -600, -330, 53, 535, 1088, 1676, 2258, 2790, 3232, 3549, 3714, 3714, 3549, 3232, 2790, 2258, 1676, 1088, 535, 53, -330, -600, -751, -789, -730, -597, -417, -218, -25, 139, 259, 327, 342, 309, 237, 140, 33, -71, -160, -225, -262, -270, -250, -209, -153, -90, -26, 32, 80, 114, 135, 142, 138, 126, 108, 87, 67, 48, 32, 19, 10, 5};
    

    initial begin
        axil_bfm = new(cfg_axi, 1);

        filter_in.data <= 0;
        filter_in.valid <= 1;
        filter_out.ready <= 1;
        //Initial status
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;

        #50;
        
        axil_bfm.write(0, 7);
        #10 axil_bfm.write('h4, taps[0]);
        #10 axil_bfm.write('h8, taps[1]);
        #10 axil_bfm.write('hc, taps[2]);
        #10 axil_bfm.write('h10, taps[3]);
        #10 axil_bfm.write('h14, taps[4]);
        #10 axil_bfm.write('h18, taps[5]);
        #10 axil_bfm.write('h1C, taps[6]);
        #10 axil_bfm.write('h20, taps[7]);
        #10 axil_bfm.write('h24, taps[8]);
        #10 axil_bfm.write('h28, taps[9]);
        #10 axil_bfm.write('h2C, taps[10]);
        #10 axil_bfm.write('h30, taps[11]);
        #10 axil_bfm.write('h34, taps[12]);
        #10 axil_bfm.write('h38, taps[13]);
        #10 axil_bfm.write('h3c, taps[14]);
        #10 axil_bfm.write('h40, taps[15]);
        #10 axil_bfm.write('h44, taps[16]);

        ->config_done;
    end


    initial begin
        @(config_done);
        forever begin
            #10;
            filter_in.data <= 'h6fff;
            filter_in.valid <= 1; 
            #100;
            filter_in.data <= 'h0fff;
            filter_in.valid <= 0; 
            #50
            filter_in.data <= 'h6fff;
            filter_in.valid <= 1; 
            #50;
            filter_in.data <= 'h0;
            filter_in.valid <= 1; 
            #190;
        end

    end


endmodule