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

module uScope #(parameter BASE_ADDRESS = 'h43C00000, TH_BASE_ADDRESS = 'h43c10000, N_TRIGGERS = 16)(
    input wire clock,
    input wire reset,
    input wire dma_done,
    output wire [N_TRIGGERS-1:0] trigger_out,
    axi_stream.slave in_1,
    axi_stream.slave in_2,
    axi_stream.slave in_3,
    axi_stream.slave in_4,
    axi_stream.slave in_5,
    axi_stream.slave in_6,
    axi_stream.slave in_7,
    axi_stream.slave in_8,
    axi_lite.master dma_axi,
    axi_stream.master out,
    Simplebus.slave sb,
    Simplebus.slave th_sb
);

    localparam CHANNEL_BUFFER_SIZE = 1024; 

    defparam combined.DATA_WIDTH = 32;
    axi_stream combined();
    defparam combined_inhibited.DATA_WIDTH = 32;
    axi_stream combined_inhibited();
    defparam combined_tlast.DATA_WIDTH = 32;
    axi_stream combined_tlast();
   
    wire manager_enable, capture_inhibit;
    wire [31:0] tlast_period;
    wire [31:0] dma_buffer_base;
    wire [31:0] dma_transfer_size;
    wire [15:0] current_sample;
    reg dma_start;



    trigger_hub #(
        .BASE_ADDRESS(TH_BASE_ADDRESS),
        .N_TRIGGERS(N_TRIGGERS) 
    ) triggers (
        .clock(clock),
        .reset(reset),
        .buffer_level(current_sample),
        .capture_done(dma_start),
        .capture_inhibit(capture_inhibit),
        .trigger_out(trigger_out),
        .sb(th_sb)
    );


    defparam combiner.MSB_DEST_SUPPORT = "TRUE";
    defparam combiner.OUTPUT_DATA_WIDTH = 32;
    scope_combiner combiner(
        .clock(clock),
        .reset(reset),
        .stream_in_1(in_1),
        .stream_in_2(in_2),
        .stream_in_3(in_3),
        .stream_in_4(in_4),
        .stream_in_5(in_5),
        .stream_in_6(in_6),
        .stream_out(combined)
    );

    always_comb begin
        combined_inhibited.data <= combined.data;
        combined.ready <= combined_inhibited.ready;
        if(capture_inhibit)begin
            combined_inhibited.valid <= 0;
        end else begin
            combined_inhibited.valid <= combined.valid;
        end
    end

    tlast_generator tlast_gen(
        .clock(clock),
        .reset(reset), 
        .period(tlast_period),
        .in_valid(combined_inhibited.valid),
        .in_data(combined_inhibited.data),
        .in_ready(combined_inhibited.ready),
        .out_valid(combined_tlast.valid),
        .out_data(combined_tlast.data),
        .out_tlast(combined_tlast.tlast),
        .out_ready(combined_tlast.ready),
        .current_sample(current_sample)
    );

    
    
    always_ff @(posedge clock) begin
        dma_start <= combined_tlast.tlast;
    end
    
    defparam manager.DMA_BASE_ADDRESS = 'h40400000;
    DMA_manager manager (
		.clock(clock),
		.reset(reset),
        .enable(manager_enable),
        .transfer_size(dma_transfer_size),
        .buffer_base_address(dma_buffer_base),
        .start_dma(dma_start),
		.dma_done(dma_done),
        .axi(dma_axi)
	);

    defparam scope_fifo.INPUT_DATA_WIDTH = 32;
    defparam scope_fifo.FIFO_DEPTH = 8192;
    axis_fifo_xpm scope_fifo(
        .clock(clock),
        .reset(reset),
        .in(combined_tlast),
        .out(out)
    );

    defparam CU.BASE_ADDRESS = BASE_ADDRESS;
    uScope_CU CU(
        .clock(clock),
        .reset(reset),
        .tlast_period(tlast_period),
        .dma_transfer_size(dma_transfer_size),
        .dma_buffer_base(dma_buffer_base),
        .dma_manager_enable(manager_enable),
        .sb(sb)
    );


endmodule