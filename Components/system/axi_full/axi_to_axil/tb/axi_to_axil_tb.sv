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
import axi_to_axil_vip_bd_axi_vip_0_0_pkg::*;


module axi_to_axil_tb();
   

    reg clk;
    reg reset = 0;
    
    AXI #(
        .ID_WIDTH(2),
        .DATA_WIDTH(128),
        .ADDR_WIDTH(49)
    ) ctrl_axi();

    axi_lite control_plane();

    axi_to_axil_vip_bd_axi_vip_0_0_mst_t mst_agent;

    wire dma_done;

  
    axi_to_axil UUT (
        .clock(clk),
        .reset(reset),
        .axi_in(ctrl_axi),
        .axi_out(control_plane)
    );

    axi_to_axil_vip_bd_wrapper VIP(
        .clock(clk),
        .reset(reset),
        .axi_in(ctrl_axi)
    );


    axi_lite_slave_sink slave_sink(
        .clock(clk),
        .reset(reset),
        .axil_in(control_plane)
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
        mst_agent = new("slave vip agent",axi_to_axil_tb.VIP.vip_bd_i.axi_vip_0.inst.IF);
        mst_agent.set_verbosity(400);
        
        //TESTS
        #30.5 reset <=1'h1;


        #70;
    
    end

endmodule