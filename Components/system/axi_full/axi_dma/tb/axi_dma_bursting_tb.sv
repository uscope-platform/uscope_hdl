// Copyright 2024 Filippo Savi
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
import axi_dma_vip_bd_axi_vip_0_0_pkg::*;


module axi_dma_bursting_tb();
   

    reg clk;
    reg reset = 0;
    
    AXI #(
        .ID_WIDTH(2),
        .DATA_WIDTH(64),
        .ADDR_WIDTH(49)
    ) axi_out();

    axi_stream #(
        .USER_WIDTH(16),
        .DEST_WIDTH(16),
        .DATA_WIDTH(64)
    ) data_in();

    axi_stream #(
        .USER_WIDTH(16),
        .DEST_WIDTH(16),
        .DATA_WIDTH(64)
    ) data_in_buf();


    axi_dma_vip_bd_axi_vip_0_0_slv_mem_t slv_agent;
    wire dma_done;

    reg trigger = 0;

    ultra_buffer #(
        .ADDRESS_WIDTH(12),
        .IN_DATA_WIDTH(32),
        .DEST_WIDTH(16), 
        .USER_WIDTH(16)
    )buffer(
        .clock(clk),
        .reset(reset),
        .enable(1),
        .trigger(trigger),
        .trigger_point(5),
        .full(buffer_full),
        .in(data_in),
        .out(data_in_buf)
    );

    axi_dma_bursting #(
        .DEST_WIDTH(16),
        .OUTPUT_AXI_WIDTH(128)
    )UUT(
        .clock(clk),
        .reset(reset), 
        .buffer_full(buffer_full),
        .dma_base_addr('h3f000000),
        .packet_length(1024),
        .data_in(data_in_buf),
        .axi_out(axi_out),
        .dma_done(dma_done)
    );

    axi_dma_vip_bd_wrapper VIP(
        .clock(clk),
        .reset(reset),
        .axi_in(axi_out)
    );

    always begin
        clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5;
    end

    reg [31:0] data_prog = 0;
    event restart_data_gen;
    initial begin 
        reset <=1'h0;
        data_in.initialize();
        slv_agent = new("slave vip agent",axi_dma_bursting_tb.VIP.vip_bd_i.axi_vip_0.inst.IF);
        slv_agent.set_verbosity(400);
        slv_agent.start_slave();
        slv_agent.mem_model.set_bresp_delay(19);
        slv_agent.mem_model.set_bresp_delay_policy(XIL_AXI_MEMORY_DELAY_NOADJUST_FIXED);

        //TESTS
        #30.5 reset <=1'h1;

        data_in.data  <= 0;
        data_in.valid <= 0;
        data_in.tlast <= 0;

        #70;
        forever begin
            for (integer i = 0; i <6000; i = i+1 ) begin
                data_in.valid <= 0;
                wait(data_in.ready==1);
                data_in.data <= i;
                data_in.dest <= i+1000;
                data_in.valid <= 1;
                data_in.tlast <= 0;
                data_prog <= data_prog + 1;
                #1;
            end
            data_in.valid <= 0;
            data_in.tlast <= 0;
            @(restart_data_gen);
            #30;
        end
    end

    initial begin
        #350 trigger = 1;
        #1 trigger = 0;
    end


    reg [31:0] axi_high_data;
    reg [31:0] axi_high_dest;
    reg [31:0] axi_low_data;
    reg [31:0] axi_low_dest;
    always_ff @(posedge axi_out.WVALID) begin
        {axi_high_dest, axi_high_data, axi_low_dest, axi_low_data} <= axi_out.WDATA;
    end

    always_ff @(posedge dma_done) begin
        ->restart_data_gen;
    end


    reg [31:0] out_cntr = 0;
    always_ff @(posedge axi_out.WVALID) begin
        if(out_cntr==1023)
            out_cntr <= 0;
        else 
            out_cntr <= out_cntr + 1;
    end


endmodule