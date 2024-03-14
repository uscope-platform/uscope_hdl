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
`include "axi_lite_BFM.svh"
`include "axi_full_bfm.svh"

module fCore_conditional_select_tb();


    reg core_clk, rst, run, done, efi_start;

    axi_stream efi_arguments();
    axi_stream efi_results();
    axi_lite axi_master();

    AXI axi_programmer();
    AXI fCore_programming_bus();

    axi_stream axis_dma_write();
    axi_stream dma_read_request();
    axi_stream dma_read_response();

    axi_lite_BFM axil_bfm;
     

    axi_xbar #(
        .NM(1),
        .NS(1),
        .ADDR_WIDTH(32),
        .SLAVE_ADDR('{0}),
        .SLAVE_MASK('{1{'hfF0000000}})
    ) programming_interconnect  (
        .clock(clock),
        .reset(reset),
        .slaves('{axi_programmer}),
        .masters(fCore_programming_bus)
    );

    event core_loaded;

    fCore #(
        .FAST_DEBUG("TRUE"),
        .MAX_CHANNELS(9),
        .CONDITIONAL_SELECT_IMPLEMENTED(1)
    ) uut(
        .clock(core_clk),
        .axi_clock(core_clk),
        .reset(rst),
        .reset_axi(rst),
        .run(run),
        .done(done),
        .efi_start(efi_start),
        .control_axi_in(axi_master),
        .axi(fCore_programming_bus),
        .axis_dma_write(axis_dma_write),
        .axis_dma_read_request(dma_read_request),
        .axis_dma_read_response(dma_read_response),
        .efi_arguments(efi_arguments),
        .efi_results(efi_results)
    );




    //clock generation
    initial core_clk = 0; 
    always #0.5 core_clk = ~core_clk;


    axi_full_bfm  bfm_in;

    reg [31:0] reg_readback;
    // reset generation
    initial begin
        axil_bfm = new(axi_master,1);
        bfm_in = new(axi_programmer, 1);
        rst <=0;
        run <= 0;
        #10.5;
        #20.5 rst <=1;
        #40;
        @(core_loaded);
        #35 axil_bfm.write(32'h43c00000, 8);
        #4 run <= 1;
        #1 run <=  0;
    end


    reg [31:0] prog [179:0];

    initial begin
        $readmemh("/home/fils/git/uscope_hdl/public/Components/system/fcore/tb/micro_bench/csel/csel.mem", prog);
        #50.5;
        for(integer i = 0; i<180; i++)begin
            #10 bfm_in.write(i*4, prog[i]);
        end
        ->core_loaded;
    end



endmodule
