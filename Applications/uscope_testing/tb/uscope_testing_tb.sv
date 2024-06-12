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
`include "interfaces.svh"
`include "axis_BFM.svh"
`include "axi_lite_BFM.svh"
`include "axi_full_bfm.svh"

import reg_maps::*;

//import axi_vip_pkg::*;
//import axi_dma_vip_bd_axi_vip_0_0_pkg::*;

module uscope_testing_tb();

    reg clk, reset;

    always begin
     clk = 1'b1;
     #0.5 clk = 1'b0;
     #0.5;
    end

    localparam timebase_addr = 'h43c00000;
    localparam scope_addr = 'h43c10200;
    localparam scope_mux_addr = 'h43c10000;
    localparam gpio_addr = 'h43c20000;


    axi_lite axi_master();
    axi_lite_BFM axil_bfm;
    wire dma_done;

    AXI #(.ID_WIDTH(2), .ADDR_WIDTH(36), .DATA_WIDTH(64))  uscope();
    
    uscope_testing_logic uut (
        .clock(clk),
        .reset(reset),
        .dma_done(dma_done),
        .axi_in(axi_master),
        .scope_out(uscope)
    );

    AXI dummy();
    axi_full_slave_sink #(
        .BUFFER_SIZE(6144),
        .BASE_ADDRESS('h3f410000),
        .BVALID_LATENCY(20)
    ) dma_sink (
        .clock(clk),
        .reset(reset),
        .axi_in(uscope)
    );
    

    initial begin  
        axil_bfm = new(axi_master, 1);
        //Initial status
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;

        #50;

        #10 axil_bfm.write(timebase_addr + reg_maps::en_gen_regs.enable, 1);
        #10 axil_bfm.write(timebase_addr + reg_maps::en_gen_regs.period, 125);
        #10 axil_bfm.write(timebase_addr + reg_maps::en_gen_regs.treshold, 10);

        #10 axil_bfm.write(scope_addr + reg_maps::uscope_regs.buffer_addr_low, 'h3f410000);
        #10 axil_bfm.write(scope_addr + reg_maps::uscope_regs.trigger_mode, 0);
        #10 axil_bfm.write(scope_addr + reg_maps::uscope_regs.trigger_level, 2);
        #10 axil_bfm.write(scope_addr + reg_maps::uscope_regs.channel_selector, 0);
        #10 axil_bfm.write(scope_addr + reg_maps::uscope_regs.acquisition_mode, 2);
        #10 axil_bfm.write(scope_addr + reg_maps::uscope_regs.trigger_point, 'h200);

        #10 axil_bfm.write(scope_mux_addr + reg_maps::uscope_mux.ch_1, 0);    
        #10 axil_bfm.write(scope_mux_addr + reg_maps::uscope_mux.ch_2, 1);
        #10 axil_bfm.write(scope_mux_addr + reg_maps::uscope_mux.ch_3, 2);
        #10 axil_bfm.write(scope_mux_addr + reg_maps::uscope_mux.ch_4, 3);
        #10 axil_bfm.write(scope_mux_addr + reg_maps::uscope_mux.ch_5, 4);
        #10 axil_bfm.write(scope_mux_addr + reg_maps::uscope_mux.ch_6, 5);

        #10 axil_bfm.write(gpio_addr + reg_maps::gpio_regs.out, 1);

    end

//    axi_dma_vip_bd_axi_vip_0_0_slv_mem_t slv_agent;

//     initial begin
//         slv_agent = new("slave vip agent",uscope_testing_tb.VIP.vip_bd_i.axi_vip_0.inst.IF);
//         slv_agent.set_verbosity(400);
//         slv_agent.start_slave();
//         slv_agent.mem_model.set_bresp_delay(19);
//         slv_agent.mem_model.set_inter_beat_gap(0);
//         slv_agent.mem_model.set_bresp_delay_policy(XIL_AXI_MEMORY_DELAY_NOADJUST_FIXED);
//     end

endmodule