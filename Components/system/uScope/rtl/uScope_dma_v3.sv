// Copyright 2024 Filippo Savi
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

module uScope_dma_v3 #(
    N_TRIGGERS = 16,
    DATA_WIDTH = 32,
    USER_WIDTH = 16,
    DEST_WIDTH = 8,
    N_STREAMS = 6,
    OUTPUT_AXI_WIDTH = 128,
    CHANNEL_SAMPLES = 1024
)(
    input wire clock,
    input wire reset,
    output wire dma_done,
    axi_stream.slave stream_in[N_STREAMS],
    AXI.master out,
    axi_lite.slave axi_in
);

    localparam TRANSFER_SIZE = CHANNEL_SAMPLES*N_STREAMS;

    axi_stream #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEST_WIDTH(DEST_WIDTH),
        .USER_WIDTH(USER_WIDTH)
    ) combined();
    
    axi_stream #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEST_WIDTH(DEST_WIDTH),
        .USER_WIDTH(USER_WIDTH)
    ) buffered();

   
    wire [63:0] dma_base_addr;
    wire [15:0] trigger_point;
    wire buffer_full, trigger;

    trigger_engine #(
        .N_CHANNELS(N_STREAMS)
    )trigger_controller(
        .clock(clock),
        .reset(reset),
        .data_in(stream_in),
        .axi_in(axi_in),
        .trigger_out(trigger),
        .trigger_point(trigger_point),
        .dma_base_addr(dma_base_addr)
    );


    axi_stream_combiner #(
        .INPUT_DATA_WIDTH(DATA_WIDTH), 
        .OUTPUT_DATA_WIDTH(DATA_WIDTH), 
        .DEST_WIDTH(DEST_WIDTH),
        .USER_WIDTH(USER_WIDTH),
        .N_STREAMS(N_STREAMS)
    )combiner(
        .clock(clock),
        .reset(reset),
        .stream_in(stream_in),
        .stream_out(combined)
    );
        
    ultra_buffer #(
        .ADDRESS_WIDTH(13),
        .DATA_WIDTH(DATA_WIDTH),
        .DEST_WIDTH(DEST_WIDTH), 
        .USER_WIDTH(USER_WIDTH)
    )buffer(
        .clock(clock),
        .reset(reset),
        .enable(1),
        .packet_length(TRANSFER_SIZE),
        .trigger(trigger),
        .trigger_point(trigger_point),
        .full(buffer_full),
        .in(combined),
        .out(buffered)
    );


    axi_dma_bursting #(
        .ADDR_WIDTH(64),
        .DEST_WIDTH(16),
        .USER_WIDTH(16),
        .OUTPUT_AXI_WIDTH(OUTPUT_AXI_WIDTH)
    )dma_engine(
        .clock(clock),
        .reset(reset), 
        .buffer_full(buffer_full),
        .dma_base_addr(dma_base_addr),
        .packet_length(TRANSFER_SIZE),
        .data_in(buffered),
        .axi_out(out),
        .dma_done(dma_done)
    );
endmodule