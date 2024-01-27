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
`timescale 10 ns / 1 ns
`include "axi_lite_BFM.svh"
`include "axis_BFM.svh"
`include "interfaces.svh"

module fcore_complex_tb();
    


   reg clk, reset;

    always begin
        clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5;
    end

    axi_lite axi_master();
    axi_lite_BFM axil_bfm;

    localparam CORE_PROGRAM = "/home/fils/git/uscope_hdl/public/Components/system/fcore_complex/tb/fCore.mem";
    localparam TT_INIT_FILE = "/home/fils/git/uscope_hdl/public/Components/system/fcore_complex/tb/fCore_iomap.mem";

    reg core_start = 0;
    reg trigger_constant = 0;
    wire core_done;

    axis_BFM dma_in_bfm;
    axi_stream dma_in();
    axi_stream dma_out();

    AXI dummy_rom();

    fcore_complex #(
        .INIT_FILE(CORE_PROGRAM),
        .TRANSLATION_TABLE_INIT_FILE(TT_INIT_FILE),
        .TRANSLATION_TABLE_INIT("FILE"),
        .MOVER_CHANNEL_NUMBER(2),
        .MOVER_SOURCE_ADDR({1,2}),
        .MOVER_TARGET_ADDR({8,6}),
        .MAX_CHANNELS(9)
    )UUT(
        .core_clock(clk),
        .interface_clock(clk),
        .core_reset(reset),
        .interface_reset(reset),
        .start(core_start),
        .done(core_done),
        .constant_capture_mode(1),
        .constant_trigger(trigger_constant),
        .control_axi(axi_master),
        .fcore_rom(dummy_rom),
        .core_dma_in(dma_in),
        .core_dma_out(dma_out)
    );



    reg [15:0] in_0;
    reg [15:0] in_1;


    reg [15:0] out_0;
    reg [15:0] out_1;
    initial begin  
        axil_bfm = new(axi_master, 1);
        dma_in_bfm = new(dma_in,1);
        dma_out.ready = 1;
        //Initial status
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20 reset <=1'h1;

        #50;
        
        #10 axil_bfm.write('h43c00000 + reg_maps::fcore_regs.n_channels, 8);
        #100;
        forever begin
            in_0 <= $urandom()%(1<<10);
            in_1 <= $urandom()%(1<<10);
            #1 dma_in_bfm.write_dest(in_0, 17);
            #1 dma_in_bfm.write_dest(in_1, 19);
            #2 core_start = 1;
            #1 core_start = 0;
            @(core_done);

            #500;
        end
        
    end

    real check_0, check_1;
    reg [31:0] check_i_0, check_i_1;

    always_ff @(posedge dma_out.valid) begin 
        if(dma_out.dest==8)begin
            out_0 = dma_out.data;
            check_0 = in_0 + 5;
            check_i_0 = check_0;
            assert (out_0 == check_i_0) 
            else $fatal("mult result error %d, got %d", check_0, out_0);
        end else if(dma_out.dest == 6)begin 
            out_1 = dma_out.data;
            check_1 = in_1*4.8;
            check_i_1 = check_1;
            assert (out_1 == check_i_1) 
            else $fatal("add result error, expected %d, got %d", check_1, out_1);
        end
    end

    initial begin
        #300;
        #10 axil_bfm.write('h43c02000 + reg_maps::axis_constant_regs.dest, 43);
        #10 axil_bfm.write('h43c03000 + reg_maps::axis_constant_regs.dest, 44);
        #10 axil_bfm.write('h43c04000 + reg_maps::axis_constant_regs.dest, 45);

        #10 axil_bfm.write('h43c02000 + reg_maps::axis_constant_regs.low, 'hBEBE);
        #10 axil_bfm.write('h43c03000 + reg_maps::axis_constant_regs.low, 'hCAFE);
        #10 axil_bfm.write('h43c04000 + reg_maps::axis_constant_regs.low, 'hBEEF);
        #200 trigger_constant = 1;
        #1 trigger_constant = 0;
    end

endmodule