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
`include "axis_BFM.svh"

import reg_maps::*;

module uscope_testing_tb();

    reg clk, reset;

    always begin
     clk = 1'b1;
     #0.5 clk = 1'b0;
     #0.5;
    end

    typedef logic[35:0] axi_address_t;
    
    localparam axi_address_t BASE_ADDRESS = 'h443c00000;

    localparam axi_address_t timebase_addr = BASE_ADDRESS;
    localparam axi_address_t scope_addr = BASE_ADDRESS +'h10200;
    localparam axi_address_t scope_mux_addr = BASE_ADDRESS +'h10000;
    localparam axi_address_t gpio_addr = BASE_ADDRESS +'h20000;


    axi_lite axi_master();
    wire dma_done;

    AXI #(.ID_WIDTH(2), .ADDR_WIDTH(36), .DATA_WIDTH(128))  uscope();
    
    uscope_testing_logic #(
        .axi_address_t(axi_address_t),
        .BASE_ADDRESS(BASE_ADDRESS)
    ) uut (
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
        axi_master.initialize_master();
        //Initial status
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;

        #50;

        #10 axi_master.write(scope_addr + reg_maps::uscope_regs.buffer_addr_low, 'h3f410000);
        #10 axi_master.write(scope_addr + reg_maps::uscope_regs.trigger_mode, 0);
        #10 axi_master.write(scope_addr + reg_maps::uscope_regs.trigger_level, 2);
        #10 axi_master.write(scope_addr + reg_maps::uscope_regs.channel_selector, 0);
        #10 axi_master.write(scope_addr + reg_maps::uscope_regs.acquisition_mode, 2);
        #10 axi_master.write(scope_addr + reg_maps::uscope_regs.trigger_point, 'h200);

        #10 axi_master.write(scope_mux_addr + reg_maps::uscope_mux.ch_1, 0);    
        #10 axi_master.write(scope_mux_addr + reg_maps::uscope_mux.ch_2, 1);
        #10 axi_master.write(scope_mux_addr + reg_maps::uscope_mux.ch_3, 2);
        #10 axi_master.write(scope_mux_addr + reg_maps::uscope_mux.ch_4, 3);
        #10 axi_master.write(scope_mux_addr + reg_maps::uscope_mux.ch_5, 4);
        #10 axi_master.write(scope_mux_addr + reg_maps::uscope_mux.ch_6, 5);

        #10 axi_master.write(timebase_addr + reg_maps::en_gen_regs.enable, 1);
        #10 axi_master.write(timebase_addr + reg_maps::en_gen_regs.period, 1000);
        #10 axi_master.write(timebase_addr + reg_maps::en_gen_regs.treshold, 10);

        #10 axi_master.write(gpio_addr + reg_maps::gpio_regs.out, 1);

    end
endmodule