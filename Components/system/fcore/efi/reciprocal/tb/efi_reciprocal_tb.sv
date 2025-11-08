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
`include "axi_lite_BFM.svh"
`include "axi_full_bfm.svh"

module efi_reciprocal_tb();



    reg core_clk, rst, run;
    wire done;

    axi_stream axis_dma_write();

    axi_stream dma_read_request();
    axi_stream dma_read_response();

    reg efi_start;
    

    event core_loaded;

    axi_lite axi_master();
    AXI #(.ADDR_WIDTH(32)) fcore_rom_link();

    axi_lite_BFM axil_bfm;
    axi_full_bfm #(.ADDR_WIDTH(32)) bfm_in;



    axi_stream efi_arguments();
    axi_stream efi_results();


    efi_reciprocal efi(
        .clock(core_clk),
        .reset(rst),
        .efi_arguments(efi_arguments),
        .efi_results(efi_results)
    );


    AXI #(.ADDR_WIDTH(32)) fCore_programming_bus[2]();

    axi_xbar #(
        .NM(1),
        .NS(2),
        .ADDR_WIDTH(32),
        .SLAVE_ADDR('{'h83c00000,'h83c80000}),
        .SLAVE_MASK('{2{'h000F0000}})
    ) programming_interconnect  (
        .clock(core_clk),
        .reset(rst),
        .slaves('{fcore_rom_link}),
        .masters(fCore_programming_bus)
    );

    fCore #(
        .FAST_DEBUG("FALSE"),
        .MAX_CHANNELS(9),
        .EFI_IMPLEMENTED(1)
    ) core(
        .clock(core_clk),
        .axi_clock(core_clk),
        .reset_axi(rst),
        .reset(rst),
        .run(run),
        .done(done),
        .efi_start(efi_start),
        .control_axi_in(axi_master),
        .axi(fCore_programming_bus[0]),
        .axis_dma_write(axis_dma_write),
        .axis_dma_read_request(dma_read_request),
        .axis_dma_read_response(dma_read_response),
        .efi_arguments(efi_arguments),
        .efi_results(efi_results)
    );

    //clock generation
    initial core_clk = 0; 
    always #0.5 core_clk = ~core_clk;

    event config_done;

    // reset generation
    initial begin
        bfm_in = new(fcore_rom_link, 1);
        axil_bfm = new(axi_master,  1);
        rst <=0;
        run <= 0;
        #10.5;
        #20.5 rst <=1;
        #35 axil_bfm.write('h43c00000,8);
        ->config_done;
        @(core_loaded);
        #4 run <= 1;
        #1 run <=  0;
    end


    localparam core_0_rom = 'h83c00000;

    reg [31:0] prog [19:0] = '{default:0};
    
    initial begin
        $readmemh("/home/fils/git/uscope_hdl/public/Components/system/fcore/efi/reciprocal/tb/test_efi_rec.mem", prog);
        #50
        @(config_done)
        for(integer i = 0; i<20; i++)begin

            #5 bfm_in.write(core_0_rom + i*4, prog[i]);
        end
        ->core_loaded;
    end



endmodule
