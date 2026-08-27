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
`include "axi_lite_BFM.svh"
`include "axis_BFM.svh"
`include "axi_full_bfm.svh"

module fCore_db_tb#(parameter EXECUTABLE = "")();


    reg clock, reset, run, done, efi_start;

    axi_stream efi_arguments();
    axi_stream efi_results();

    axi_lite_BFM axil_bfm;
    axis_BFM dma_bfm;
    axi_lite axi_master();


    axi_full_bfm #(.ADDR_WIDTH(32)) bfm_in;
    AXI #(.ADDR_WIDTH(32)) axi_programmer();
    AXI #(.ADDR_WIDTH(32)) fCore_programming_bus();

    axi_stream axis_dma_write();
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
        .RECIPROCAL_PRESENT(1),
        .BITMANIP_IMPLEMENTED(1),
        .LOGIC_IMPLEMENTED(1),
        .EFI_IMPLEMENTED(1),
        .FULL_COMPARE(1),
        .CONDITIONAL_SELECT_IMPLEMENTED(1),
        .ENABLE_DEBUG_INTERFACE("TRUE")
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

    reg test_started= 0;
    //clock generation
    initial clock = 0;
    always #0.5 clock = ~clock;
    reg[31:0] tmp_arg = 232;


    reg [31:0] reg_readback;
    // reset generation
    initial begin
        dma_bfm = new(axis_dma_write,1);
        axil_bfm = new(axi_master,1);
        bfm_in = new(axi_programmer, 1);

        dma_read_request.valid <= 0;
        dma_read_request.data <= 0;
        reset <=0;
        run <= 0;
        #10.5;
        #20.5 reset <=1;
        #40;
        @(core_loaded);
        #100;
        #5 bfm_in.write((4096+1)*4, 'hCAFEBEBE);
        #5 bfm_in.write((4096+2)*4, 'hDEADBEEF);
        #5 bfm_in.write((4096+3)*4, 'hBEEFBEBE);
        #5 bfm_in.write((4096+4)*4, 'hDEADCAFE);
        #100;
        #5 bfm_in.read((4096+1)*4, reg_readback);
        #5 bfm_in.read((4096+2)*4, reg_readback);
        #5 bfm_in.read((4096+3)*4, reg_readback);
        #5 bfm_in.read((4096+4)*4, reg_readback);
        #100;
        #5 bfm_in.read((0)*4, reg_readback);
        #5 bfm_in.read((1)*4, reg_readback);
        #5 bfm_in.read((2)*4, reg_readback);
        #5 bfm_in.read((3)*4, reg_readback);
    end    

    reg [31:0] prog [0:17] = {'hd0003,'hc,'h10002,'h30004,'hc,'h40028,'h26,'h43160000,'h66,'h43480000,'h6085b,'h0,'h0,'h0,'h26,'h42000000,'h60842,'hc};
    string file_path;
    initial begin
        file_path = $sformatf("%s/tb/micro_bench/common_io/common_io.mem", EXECUTABLE);
        $readmemh(file_path, prog);
        #50.5;
        for(integer i = 0; i<18; i++)begin
            #5 bfm_in.write(i*4, prog[i]);
        end
        ->core_loaded;
    end



endmodule
