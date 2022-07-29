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
`include "interfaces.svh"

module merge_sorter #(
    parameter DATA_WIDTH=32,
    parameter DEST_WIDTH=32,
    parameter USER_WIDTH=32,
    parameter MAX_SORT_LENGTH=32
)(
    input wire clock,
    input wire reset,
    input wire start,
    input wire [15:0] data_length,
    output reg done,
    axi_stream.slave input_data,
    axi_stream.master output_data
);


    reg [$clog2(MAX_SORT_LENGTH/8-1):0] chunk_counter = 0;
    reg enable_batcher_sort = 0;
        
    axi_stream #(.DATA_WIDTH(DATA_WIDTH), .DEST_WIDTH(DEST_WIDTH), .USER_WIDTH(USER_WIDTH)) batcher_out();

    wire [$clog2(MAX_SORT_LENGTH/8-1):0] selected_chunk_size;
    
    batcher_sorter_8_serial #(
       .DATA_WIDTH(DATA_WIDTH),
       .DEST_WIDTH(DEST_WIDTH),
       .USER_WIDTH(USER_WIDTH)
    )in_sorter(
        .clock(clock),
        .chunk_size(selected_chunk_size),
        .data_in(input_data),
        .data_out(batcher_out)
    );

    reg [$clog2(MAX_SORT_LENGTH/8-1):0] n_complete_chunks  = 0;
    reg [2:0] last_chunk_size = 0;


    assign selected_chunk_size = chunk_counter==n_complete_chunks &last_chunk_size != 0 ? last_chunk_size : 8;


    reg [2:0] input_data_counter = 0;
    
    always_ff @(posedge clock) begin
        done <= 0;
        enable_batcher_sort <= 1;
        if(start)begin
            n_complete_chunks <= data_length/8;
            chunk_counter <= 0;
            last_chunk_size <= data_length%8;
        end

        if(input_data.valid)begin
            if(chunk_counter == n_complete_chunks)begin
                if(input_data_counter == last_chunk_size-1) begin
                    input_data_counter <= 0;
                    enable_batcher_sort<= 0;
                    chunk_counter <= chunk_counter + 1;
                end else begin
                    input_data_counter <= input_data_counter + 1;
                end
            end else begin 
                if(input_data_counter == 7) begin
                    input_data_counter <= 0;
                    chunk_counter <= chunk_counter + 1;
                end else begin
                    input_data_counter <= input_data_counter + 1;
                end
            end
        end
    end


    reg batches_counter_working = 0;
    reg [$clog2(MAX_SORT_LENGTH-1):0] batches_counter  = 0;
    always_ff @(posedge clock) begin
        if(~batches_counter_working)begin
            batches_counter <= 0;
        end
        batcher_out.tlast <= 0;
        if(start) begin
            batches_counter_working <= 1;
            batches_counter <= 0;
        end
        if(batcher_out.valid & batches_counter_working) begin
            batches_counter <= batches_counter + 1;
            if(batches_counter == (n_complete_chunks*8 + last_chunk_size)-2) begin
                batcher_out.tlast <= 1;
                batches_counter_working <= 0;
            end

        end
    end

    merging_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEST_WIDTH(DEST_WIDTH),
        .USER_WIDTH(USER_WIDTH),
        .MAX_SORT_LENGTH(MAX_SORT_LENGTH),
        .BASE_CHUNK_SIZE(8)
    )merger (
        .clock(clock),
        .reset(reset),
        .n_chunks_in(n_complete_chunks),
        .last_chunk_size(last_chunk_size),
        .data_in(batcher_out),
        .data_out(output_data)
    );



endmodule