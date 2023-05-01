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
        .PARALLEL_ORDER(8)
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

    reg signed [15:0] taps [8:0];
    initial begin 
        taps[0] = 'hfb64;
        taps[1] = 'hf531;
        taps[2] = 'h0d98;
        taps[3] = 'h4fd4;
        taps[4] = 'h7808;
        taps[5] = 'h4fd4;
        taps[6] = 'h0d98;
        taps[7] = 'hf531;
        taps[8] = 'hfb64;
    end


    initial begin
        axil_bfm = new(cfg_axi, 1);

        filter_in.data <= '0;
        filter_in.valid <= 1;
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

        ->config_done;
    end


    initial begin
        @(config_done);
        #100;
        filter_in.data <= 'h0fff;
        filter_in.valid <= 1;
    end


endmodule