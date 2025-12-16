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

module fCore_generic_2_inputs_tb#(parameter EXECUTABLE = "/home/filssavi/git/uplatform-hdl/public/Components/system/fcore")();


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
    reg[31:0] tmp_arg = 232;

    always_ff @(posedge clock) begin
        efi_arguments.ready  <= 1;
        if(efi_arguments.valid) tmp_arg = efi_arguments.data;
    end

    initial begin
    efi_results.dest = 0;
    @(core_loaded);
    efi_results.tlast = 0;
    efi_results.valid = 0;
    efi_results.data = 0;
    @(negedge efi_arguments.valid)

    #5;
    efi_results.data = tmp_arg;
    efi_results.tlast = 1;
    efi_results.valid = 1;
    #1;
    efi_results.data = 0;
    efi_results.tlast = 0;
    efi_results.valid = 0;
    end
    event send_inputs;
    event inputs_ready;
    event output_done;
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
        #35 axil_bfm.write(32'h43c00000, 4);

        forever begin
            #100;
            ->send_inputs;
            @(inputs_ready);
            run <=1;
            #1;
            run <=0;
            @(output_done);
        end

    end

    reg [31:0] prog [249:0] = '{default:0};
    string file_path;
    initial begin
        file_path = $sformatf("%s/tb/micro_bench/generic_2_input/generic_2.mem", EXECUTABLE);
        $readmemh(file_path, prog);
        #50.5;
        for(integer i = 0; i<250; i++)begin
            #5 bfm_in.write(i*4, prog[i]);
        end
        ->core_loaded;
    end

    event a_ready;

    reg [31:0] in_counter = 0;
    reg [31:0] op_a [249:0] = '{default:0};
    reg [31:0] op_b [249:0] = '{default:0};
    reg [31:0] op_c [249:0] = '{default:0};
    string file_path_a, file_path_b;
    initial begin
        file_path_a = $sformatf("%s/tb/micro_bench/generic_2_input/op_a.mem", EXECUTABLE);
        $readmemh(file_path_a, op_a);
        forever begin
            @(send_inputs);
            #1 dma_bfm.write_dest(op_a[in_counter], 2);
            #1 dma_bfm.write_dest(op_a[in_counter], 'h10002);
            ->a_ready;
        end
    end


    initial begin
        file_path_b = $sformatf("%s/tb/micro_bench/generic_2_input/op_b.mem", EXECUTABLE);
        $readmemh(file_path_b, op_b);
        forever begin
            @(a_ready);
            #1 dma_bfm.write_dest(op_b[in_counter], 3);
            #1 dma_bfm.write_dest(op_b[in_counter], 'h10003);
            in_counter <= in_counter + 1;
            #2;
            ->inputs_ready;
        end
    end


    initial begin
        file_path_b = $sformatf("%s/tb/micro_bench/generic_2_input/op_b.mem", EXECUTABLE);
        $readmemh(file_path_b, op_b);
        forever begin
            @(a_ready);
            #1 dma_bfm.write_dest(op_b[in_counter], 3);
            #1 dma_bfm.write_dest(op_b[in_counter], 'h10003);
            in_counter <= in_counter + 1;
            #2;
            ->inputs_ready;
        end
    end

    always begin
        @(posedge done);
        dma_read_request.data <= 4;
        dma_read_request.valid <= 1;
        #1 dma_read_request.valid <= 0;
        #5;
        ->output_done;
    end

    always begin
        @(posedge dma_read_response.valid);
        #0.5;
        $display("Received output %d for input index %d", dma_read_response.data, in_counter-1);
        op_c[in_counter-1] <= dma_read_response.data;
    end

endmodule
