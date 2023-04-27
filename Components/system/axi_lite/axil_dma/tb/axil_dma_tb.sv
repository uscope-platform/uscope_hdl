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
`include "interfaces.svh"
`include "axi_lite_BFM.svh"


import axi_vip_pkg::*;
import axil_dma_vip_bd_axi_vip_0_0_pkg::*;


module axil_dma_tb();
   

    reg clk;
    reg reset = 0;
    
    axi_lite axi_in();
    axi_lite axi_out();
    axi_stream data_in();

    event config_done;

    axi_lite_BFM axil_bfm;

    axil_dma_vip_bd_axi_vip_0_0_slv_mem_t slv_agent;

    axil_dma UUT(
        .clock(clk),
        .reset(reset), 
        .enable(1),
        .axi_in(axi_in),
        .data_in(data_in),
        .axi_out(axi_out)
    );

    axil_dma_vip_bd_wrapper VIP(
        .clock(clk),
        .reset(reset),
        .axi(axi_out)
    );

    always begin
        clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5;
    end
    
    initial begin 
        reset <=1'h0;
        data_in.initialize();
        slv_agent = new("slave vip agent",axil_dma_tb.VIP.vip_bd_i.axi_vip_0.inst.IF);
        slv_agent.set_verbosity(400);
        slv_agent.start_slave();

        //TESTS
        #30.5 reset <=1'h1;


        #20;
        for (integer i = 0; i <101; i = i+1 ) begin
            data_in.data <= $urandom();
            data_in.valid <= 1;
            #1;    
            @(data_in.ready);
        end
        data_in.valid <= 0;
    end


    initial begin 
        axil_bfm = new(axi_in, 1);

        #50;
        axil_bfm.write(0, 'h3f000000);
        axil_bfm.write('h04, 120);
        
        ->config_done;
    end


endmodule