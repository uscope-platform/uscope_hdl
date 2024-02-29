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

module uScope_dma #(
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
    ) in_buffered[N_STREAMS]();
   
    axi_stream #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEST_WIDTH(DEST_WIDTH),
        .USER_WIDTH(USER_WIDTH)
    ) combined();
    
   
    wire [63:0] dma_base_addr;
    wire [15:0] trigger_point;

    wire [N_STREAMS-1:0] buffer_full;
    wire trigger;

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


    generate
        genvar i;
        for(i = 0; i<N_STREAMS; i++)begin

            ultra_buffer #(
                .ADDRESS_WIDTH(10),
                .DATA_WIDTH(DATA_WIDTH),
                .DEST_WIDTH(DEST_WIDTH), 
                .USER_WIDTH(USER_WIDTH)
            )buffer(
                .clock(clock),
                .reset(reset),
                .enable(1),
                .packet_length(CHANNEL_SAMPLES),
                .trigger(trigger),
                .trigger_point(trigger_point),
                .full(buffer_full[i]),
                .in(stream_in[i]),
                .out(in_buffered[i])
            );
        
        end
    endgenerate


    wire dma_start;
    assign dma_start = |buffer_full;

    channel_serializer #(
        .N_CHANNELS(N_STREAMS),
        .SAMPLES_PER_CHANNEL(CHANNEL_SAMPLES),
        .DATA_WIDTH(DATA_WIDTH),
        .DEST_WIDTH(DEST_WIDTH),
        .USER_WIDTH(USER_WIDTH)
    )serializer(
        .clock(clock),
        .reset(reset),
        .trigger(dma_start),
        .data_in(in_buffered),
        .data_out(combined)
    );
    
    axi_dma_bursting #(
        .ADDR_WIDTH(64),
        .DEST_WIDTH(16),
        .USER_WIDTH(16),
        .OUTPUT_AXI_WIDTH(OUTPUT_AXI_WIDTH)
    )dma_engine(
        .clock(clock),
        .reset(reset), 
        .buffer_full(dma_start),
        .dma_base_addr(dma_base_addr),
        .packet_length(TRANSFER_SIZE),
        .data_in(combined),
        .axi_out(out),
        .dma_done(dma_done)
    );
endmodule