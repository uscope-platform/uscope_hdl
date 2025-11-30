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

module fCore_common_io_tb#(parameter EXECUTABLE = "")();


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
        .RECIPROCAL_PRESENT(0),
        .BITMANIP_IMPLEMENTED(1),
        .LOGIC_IMPLEMENTED(1),
        .EFI_IMPLEMENTED(1),
        .FULL_COMPARE(1),
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

    reg test_started= 0;
    //clock generation
    initial clock = 0; 
    always #0.5 clock = ~clock;


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
        test_started = 1;
        #35 axil_bfm.write(32'h43c00000, 1);
        #100 dma_bfm.write_dest($shortrealtobits(1.0), 2);
        #100 dma_bfm.write_dest($shortrealtobits(5.0), 3);
        #12 run <= 1;
        #1 run <=  0;
        #1
        #1 dma_bfm.write_dest($shortrealtobits(7.0), 3);
        #1 dma_bfm.write_dest($shortrealtobits(8.0), 3);
        @(done);
        #10;
        dma_read_request.data <= 4;
        dma_read_request.valid <= 1;
        #1 dma_read_request.valid <= 0;
        #500000000;
        #2;
        if(dma_read_response.data  != $shortrealtobits(6.0))begin
            $display ("RESULT ERROR: Wrong result for test 1, received %d, expected 6.0", dma_read_response.data);
        //    $finish; 
        end
        #10
        dma_read_request.data <= 'h10004;
        dma_read_request.valid <= 1;
        #1 dma_read_request.valid <= 0;
        #2;
        if(dma_read_response.data != $shortrealtobits(5.0))begin
            $display ("RESULT ERROR: Wrong result for test 2, received %d, expected 6.0t 2", dma_read_response.data);
        //    $finish; 
        end

        #4 run <= 1;
        #1 run <=  0;
        #1
        #1 dma_bfm.write_dest($shortrealtobits(1.0), 3);
        #1 dma_bfm.write_dest($shortrealtobits(74.0), 3);

    end


    reg [31:0] prog [249:0];
    string file_path;
    initial begin
        file_path = $sformatf("%s/tb/micro_bench/common_io/common_io.mem", EXECUTABLE);
        $readmemh(file_path, prog);
        #50.5;
        for(integer i = 0; i<250; i++)begin
            #5 bfm_in.write(i*4, prog[i]);
        end
        ->core_loaded;
    end



endmodule
