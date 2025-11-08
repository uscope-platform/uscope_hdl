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
`include "axi_full_bfm.svh"

module fcore_complex_tb();


   reg clk, reset;

    always begin
        clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5;
    end

    axi_lite axi_master();
    axi_lite_BFM axil_bfm;


    reg core_start = 0;
    reg trigger_constant = 0;
    wire core_done;

    axis_BFM dma_in_bfm;
    axi_stream dma_in();
    axi_stream dma_out();


    localparam test_constant_in = 0;
    localparam test_dma_in = 1;
    localparam test_both =0;


    initial begin
        if(test_dma_in == 1 && test_constant_in==1)begin
            $display("-------------------------------------------------------------------------------------");
            $display("-------------------------------------------------------------------------------------");
            $display("ERROR: SELECT ONLY ONE OF THE TEST PATTERNS");
            $display("-------------------------------------------------------------------------------------");
            $display("-------------------------------------------------------------------------------------");
            $fatal();
        end 
    end

    AXI fcore_rom_link();
    AXI fCore_programming_bus();
    event core_loaded, start_loading;




    axi_xbar #(
        .NM(1),
        .NS(1),
        .ADDR_WIDTH(32),
        .SLAVE_ADDR('{'h43c00000}),
        .SLAVE_MASK('{1{'h000F0000}})
    ) programming_interconnect  (
        .clock(clk),
        .reset(reset),
        .slaves('{fcore_rom_link}),
        .masters('{fCore_programming_bus})
    );

    fcore_complex #(
        .MOVER_CHANNEL_NUMBER(16),
        .MAX_CHANNELS(9)
    )UUT(
        .core_clock(clk),
        .interface_clock(clk),
        .core_reset(reset),
        .interface_reset(reset),
        .repeat_outputs(1),
        .start(core_start),
        .done(core_done),
        .control_axi(axi_master),
        .fcore_rom(fCore_programming_bus),
        .core_dma_in(dma_in),
        .core_dma_out(dma_out)
    );

    reg [15:0] in_0_addr = 17;
    reg [15:0] in_1_addr = 19;

    reg [15:0] out_0_addr = 7;
    reg [15:0] out_1_addr = 12;

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
        ->start_loading;
        #50;
        
        @(core_loaded);
    


        #10 axil_bfm.write('h43c02000 + reg_maps::fcore_constant_engine.active_channels, 3);
        #10 axil_bfm.write('h43c02000 + reg_maps::fcore_constant_engine.const_user, 'h38);

        #10 axil_bfm.write('h43c00000 + reg_maps::fcore_regs.n_channels, 8);


        #10 axil_bfm.write('h43c01000 + reg_maps::axis_dynamic_dma_regs.addr_0, {out_1_addr, 16'h2});
        #10 axil_bfm.write('h43c01000 + reg_maps::axis_dynamic_dma_regs.user_0, 'h38);

        #10 axil_bfm.write('h43c01000 + reg_maps::axis_dynamic_dma_regs.addr_1, {out_0_addr, 16'h1});
        #10 axil_bfm.write('h43c01000 + reg_maps::axis_dynamic_dma_regs.user_1, 'h38);

        #10 axil_bfm.write('h43c01000 + reg_maps::axis_dynamic_dma_regs.n_ch, 2);

        #100;
        forever begin
            in_0 <= $urandom()%(1<<10);
            in_1 <= $urandom()%(1<<10);

            if(test_dma_in)begin
                #1 dma_in_bfm.write_dest(in_0, in_0_addr);
                #1 dma_in_bfm.write_dest(in_1, in_1_addr);
            end

            if(test_constant_in) begin
                
                #1 axil_bfm.write('h43c02000 + reg_maps::fcore_constant_engine.const_selector, 'h0000);
                #1 axil_bfm.write('h43c02000 + reg_maps::fcore_constant_engine.const_dest, in_0_addr);
                #1 axil_bfm.write('h43c02000 + reg_maps::fcore_constant_engine.const_lsb, in_0);

                #1 axil_bfm.write('h43c02000 + reg_maps::fcore_constant_engine.const_selector, 'h0001);
                #1 axil_bfm.write('h43c02000 + reg_maps::fcore_constant_engine.const_dest, in_1_addr);
                #1 axil_bfm.write('h43c02000 + reg_maps::fcore_constant_engine.const_lsb, in_1);

            end

            if(test_both) begin
                #1 dma_in_bfm.write_dest(in_0, in_0_addr);

                #1 axil_bfm.write('h43c02000 + reg_maps::fcore_constant_engine.const_selector, 'h0001);
                #1 axil_bfm.write('h43c02000 + reg_maps::fcore_constant_engine.const_dest, in_1_addr);
                #1 axil_bfm.write('h43c02000 + reg_maps::fcore_constant_engine.const_lsb, in_1);
            end
            
            #40 core_start = 1;
            #1 core_start = 0;
            @(core_done);

            #500;
        end
        
    end

    real check_0, check_1;
    reg [31:0] check_i_0, check_i_1;

    always_ff @(posedge dma_out.valid) begin 
        if(dma_out.dest==out_0_addr)begin
            out_0 = dma_out.data;
            check_0 = in_0 + 5;
            check_i_0 = check_0;
            assert (out_0 == check_i_0) 
            else $fatal("mult result error %d, got %d", check_0, out_0);
        end else if(dma_out.dest == out_1_addr)begin 
            out_1 = dma_out.data;
            check_1 = in_1*4.8;
            check_i_1 = check_1;
            assert (out_1 == check_i_1) 
            else $fatal("add result error, expected %d, got %d", check_1, out_1);
        end
    end

    axi_full_bfm #(.ADDR_WIDTH(32)) bfm_in;

    reg [31:0] prog [349:0]  = '{default:0};
    reg  [31:0] addr = 0;
    
    initial begin
        bfm_in = new(fcore_rom_link, 1);
        $readmemh("/home/fils/git/uscope_hdl/public/Components/system/fcore_complex/tb/fCore.mem", prog);
        @(start_loading);
        for(integer i = 0; i<30; i++)begin
            #5 bfm_in.write(0 + i*4, prog[i]);
        end
        ->core_loaded;
    end



endmodule