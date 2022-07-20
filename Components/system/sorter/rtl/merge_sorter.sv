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
    parameter MAX_SORT_LENGTH=32
)(
    input wire clock,
    input wire reset,
    input wire start,
    input wire [15:0] data_length,
    output wire done,
    axi_stream.slave input_data,
    axi_stream.master output_data
);


    reg [DATA_WIDTH-1:0] transfer_buffer [7:0];
    reg [3:0] current_chunk_size = 8;
    wire sorter_out_valid;
    reg enable_batcher_sort;
        
    batcher_sorter_8_serial #(
       .DATA_WIDTH(DATA_WIDTH)
    )in_sorter(
        .clock(clock),
        .reset(reset),
        .data_in(input_data),
        .chunk_size(current_chunk_size),
        .data_out(transfer_buffer),
        .data_out_valid(sorter_out_valid),
        .data_out_ready(enable_batcher_sort)
    );

    reg [$clog2(MAX_SORT_LENGTH)-1:0] input_data_counter = 0;

    always_ff @(posedge clock) begin
        if(state == sorter_idle) begin
             enable_batcher_sort <= 1;
        end
        if(input_data_counter == shadow_data_length-2) begin
            enable_batcher_sort <= 0;
        end
        if(input_data.valid)begin
            input_data_counter <= input_data_counter + 1;
        end
    end



    reg [15:0] shadow_data_length;
    reg [$clog2(MAX_SORT_LENGTH/8-1):0] n_complete_chunks  = 0;
    reg [2:0] last_chunk_size = 0;
    

    reg [$clog2(MAX_SORT_LENGTH/8-1):0] chunk_counter  = 0;


    reg [$clog2(MAX_SORT_LENGTH)-1:0] mem_a_addr_w;
    reg [DATA_WIDTH-1:0] mem_a_data_w;

    reg start_merging= 0;

    enum logic [1:0] { 
        sorter_idle = 0,
        sorter_batching = 1,
        sorter_merging = 2
    } state = sorter_idle;

    always_ff @(posedge clock) begin
        if(~reset) begin
        end else begin
            case (state)
                sorter_idle:begin
                    if(start) begin
                        shadow_data_length <= data_length;
                        n_complete_chunks <= data_length/8;
                        last_chunk_size <= data_length%8;
                        state <= sorter_batching;
                    end
                end
                sorter_batching:begin
                    if(sorter_out_valid)begin
                        chunk_counter <= chunk_counter+1;
                    end
                    if(chunk_counter == n_complete_chunks-1) begin
                        if(sorter_out_valid)begin
                            state <= sorter_merging;
                        end
                        current_chunk_size <= last_chunk_size;
                    end else begin
                        current_chunk_size <= 8;
                    end
                end
                sorter_merging:begin
                    
                end 
            endcase



        end
    end

    merging_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_SORT_LENGTH(MAX_SORT_LENGTH),
        .BASE_CHUNK_SIZE(8)
    )merger (
        .clock(clock),
        .reset(reset),
        .start_merging(),
        .input_data(mem_a_data_w),
        .input_addr(mem_a_addr_w)
    );



endmodule