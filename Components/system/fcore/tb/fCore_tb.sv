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
`include "SimpleBus_BFM.svh"

module fCore_tb();

    `define DEBUG

    reg core_clk, io_clk, rst, run,programming_start;
    wire done;
    
    axi_stream op_a();
    axi_stream op_res();
    Simplebus s();
    AXI axi_programmer();
    axi_stream axis_dma();

    simplebus_BFM BFM;

    localparam RECIPROCAL_PRESENT = 0;
     
    defparam uut.FAST_DEBUG = "TRUE";
    defparam uut.MAX_CHANNELS = 9;
    defparam uut.INIT_FILE = "/home/fils/git/uscope_hdl/Components/system/fcore/tb/test_sat.mem";
    defparam uut.dma_ep.LEGACY_READ = 0;
    defparam uut.executor.RECIPROCAL_PRESENT = RECIPROCAL_PRESENT;
    fCore uut(
        .clock(core_clk),
        .reset(rst),
        .run(run),
        .done(done),
        .sb(s),
        .axi(axi_programmer),
        .axis_dma(axis_dma)
    );

    //clock generation
    initial core_clk = 0; 
    always #0.5 core_clk = ~core_clk;

    //clock generation
    initial begin
        io_clk = 0; 
    
        forever begin
            #1 io_clk = ~io_clk; 
        end 
    end

    reg [31:0] reg_readback;
    // reset generation
    initial begin
        BFM = new(s,1);
         
        
        rst <=0;

        op_a.initialize();
        op_res.initialize();
        op_res.ready <= 1;
        run <= 0;
        #10.5;
        #20.5 rst <=1;
        #35 BFM.write(32'h43c00000,8);
        #4; run <= 1;
        #5 run <=  0;
    end
    reg [31:0] expected_results [12:0];
    localparam CORE_DMA_BASE_ADDRESS = 32'h43c00004;
    
    initial begin
        if(RECIPROCAL_PRESENT==1) begin
            expected_results <= {'h428C0000,'h0000000c,'h40a00000,'h3c6d7304,'h40800000,'h40400000,'hc0800000,'h428c0000,'h40400000,'hc0c00000,'hc0800000,'h40800000,'h0};
        end else begin
            expected_results <= {'h428C0000,'h0000000c,'h40a00000,'h0,'h40800000,'h40400000,'hc0800000,'h428c0000,'h40400000,'hc0c00000,'hc0800000,'h40800000,'h0};
        end
        @(posedge done) $display("femtoCore Processing Done");
        for (integer i = 0; i<13; i++) begin
            BFM.read(CORE_DMA_BASE_ADDRESS+4*i, reg_readback);
            if(reg_readback!=expected_results[i]) $display("Register %d  Wrong Value detected. Expected %h Got %h",i,expected_results[i],reg_readback);
        end

    end

  

endmodule
