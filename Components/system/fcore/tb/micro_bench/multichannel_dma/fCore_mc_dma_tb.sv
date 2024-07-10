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
`include "axis_BFM.svh"
`include "axi_full_bfm.svh"

module fCore_mc_dma_tb();


    reg clock, reset, run, done, efi_start;

    axi_stream efi_arguments();
    axi_stream efi_results();

    axi_lite_BFM axil_bfm;
    axi_lite axi_master();


    axi_full_bfm #(.ADDR_WIDTH(32)) bfm_in;
    AXI #(.ADDR_WIDTH(32)) axi_programmer();
    AXI #(.ADDR_WIDTH(32)) fCore_programming_bus();


    axis_BFM wr_bfm;
    axi_stream axis_dma_write();

    axis_BFM rd_bfm;
    axi_stream dma_read_request();

    axi_stream dma_read_response();


    axi_xbar #(
        .NM(1),
        .NS(1),
        .ADDR_WIDTH(32),
        .SLAVE_ADDR('{0}),
        .SLAVE_MASK('{1{'hfF00000}})
    ) programming_interconnect  (
        .clock(clock),
        .reset(reset),
        .slaves('{axi_programmer}),
        .masters('{fCore_programming_bus})
    );

    event core_loaded;

    fCore #(
        .FAST_DEBUG("TRUE"),
        .MAX_CHANNELS(9),
        .CONDITIONAL_SELECT_IMPLEMENTED(1)
    ) uut(
        .clock(clock),
        .axi_clock(clock),
        .reset(reset),
        .reset_axi(reset),
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
    initial clock = 0; 
    always #0.5 clock = ~clock;


    reg [31:0] reg_readback;
    // reset generation
    initial begin
        axil_bfm = new(axi_master,1);
        bfm_in = new(axi_programmer, 1);

        wr_bfm = new(axis_dma_write,1);
        rd_bfm = new(dma_read_request,1);
        reset <=0;
        run <= 0;
        #10.5;
        #20.5 reset <=1;
        #40;
        @(core_loaded);
        #5 wr_bfm.write_dest($shortrealtobits(1.0), {16'h0, 16'h2});
        #5 wr_bfm.write_dest($shortrealtobits(1.0), {16'h0, 16'h3});

        #5 wr_bfm.write_dest($shortrealtobits(2.0), {16'h1, 16'h2});
        #5 wr_bfm.write_dest($shortrealtobits(2.0), {16'h1, 16'h3});

        #5 wr_bfm.write_dest($shortrealtobits(3.0), {16'h2, 16'h2});
        #5 wr_bfm.write_dest($shortrealtobits(3.0), {16'h2, 16'h3});

        #5 wr_bfm.write_dest($shortrealtobits(4.0), {16'h3, 16'h2});
        #5 wr_bfm.write_dest($shortrealtobits(4.0), {16'h3, 16'h3});
        
        #35 axil_bfm.write(32'h43c00000, 8);
        #4 run <= 1;
        #1 run <=  0;
        @(done);
        #40;
        #5 rd_bfm.write({16'h0, 16'd20});
        @(dma_read_response.valid==1);
        #1 reg_readback <= dma_read_response.data;
        if(dma_read_response.data != $shortrealtobits(2.0))begin
            $display ("RESULT ERROR: Wrong result on channel 0");
            $finish; 
        end

        #5 rd_bfm.write({16'h1, 16'd20});
        @(dma_read_response.valid==1);
        #1 reg_readback <= dma_read_response.data;
        if(dma_read_response.data != $shortrealtobits(4.0))begin
            $display ("RESULT ERROR: Wrong result on channel 1");
            $finish; 
        end
        #5 rd_bfm.write({16'h2, 16'd20});
        @(dma_read_response.valid==1);
        #1 reg_readback <= dma_read_response.data;
        if(dma_read_response.data != $shortrealtobits(6.0))begin
            $display ("RESULT ERROR: Wrong result on channel 2");
            $finish; 
        end
        #5 rd_bfm.write({16'h3, 16'd20});
        @(dma_read_response.valid==1);
        #1 reg_readback <= dma_read_response.data;
        if(dma_read_response.data != $shortrealtobits(8.0))begin
            $display ("RESULT ERROR: Wrong result on channel 3");
            $finish; 
        end
        #1000;

        $display ("SIMULATION SUCCESSFUL");
        $finish; 
    end


    reg [31:0] prog [179:0];

    initial begin
        $readmemh("/home/fils/git/uscope_hdl/public/Components/system/fcore/tb/micro_bench/multichannel_dma/mc_dma.mem", prog);
        #50.5;
        for(integer i = 0; i<30; i++)begin
            #5 bfm_in.write(i*4, prog[i]);
        end
        ->core_loaded;
    end



endmodule
