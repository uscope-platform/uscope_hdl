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

    reg [15:0] shadow_data_length;

    reg [DATA_WIDTH-1:0] input_buffer [7:0];
    wire [DATA_WIDTH-1:0] sorter_out [7:0];

    reg sorter_in_valid = 0;
    wire sorter_out_valid;

    batcher_sorter_8 #(
        .DATA_WIDTH(DATA_WIDTH)
    )sorting_core(
        .clock(clock),
        .reset(reset),
        .data_in(input_buffer),
        .data_in_valid(sorter_in_valid),
        .data_out(sorter_out),
        .data_out_valid(sorter_out_valid)
    );
    
    reg [2:0] in_buffer_level = 0;
    reg [DATA_WIDTH-1:0] transfer_buffer [7:0];
    reg transfer_start = 0;

    always_ff @(posedge clock) begin
        if(~reset) begin
            in_buffer_level <= 0;
            
        end else begin

            if(sorter_in_valid) begin
                for (integer i = 0; i<8; i= i+1) begin
                    input_buffer[i] <= 0;
                end
            end
            
            transfer_start <= 0;

            if(input_data.valid) begin
                input_buffer[in_buffer_level] <= input_data.data;
                in_buffer_level <= in_buffer_level + 1;
            end

            if(sorter_out_valid) begin
                transfer_buffer <= sorter_out;
                transfer_start <= 1;
            end
        end
    end


    reg [$clog2(MAX_SORT_LENGTH)-1:0] received_data_count = 0;

    always_ff @(posedge clock) begin
        if(~reset) begin
            input_data.ready <= 1;
            sorter_in_valid <= 0;
        end else begin
             sorter_in_valid <= 0;
            if(input_data.valid) begin
                received_data_count <= received_data_count + 1;
            end
            if(input_data.valid && received_data_count%8==7) begin
                sorter_in_valid <= 1;
            end
            if(received_data_count==shadow_data_length-1)begin
                input_data.ready <= 0;
            end
            if(received_data_count==shadow_data_length) begin
                sorter_in_valid <= 1;
                received_data_count <= 0;
            end
        end
    end
    

    reg [$clog2(MAX_SORT_LENGTH/8-1):0] n_complete_chunks  = 0;
    reg [2:0] last_chunk_size = 0;
    
    reg [2:0] transfer_index = 0;

    reg [$clog2(MAX_SORT_LENGTH)-1:0] sort_buffer_level = 0;
    reg [$clog2(MAX_SORT_LENGTH/8-1):0] current_chunk  = 0;

    reg [$clog2(MAX_SORT_LENGTH)-1:0] mem_a_addr_w;
    reg [DATA_WIDTH-1:0] mem_a_data_w;

    enum logic [2:0] { 
        idle_sorter = 0,
        wait_transfer_start = 1,
        read_full_chunk = 2,
        read_last_chunk = 3,
        wait_merge_unit = 4
    } sorter_state = idle_sorter;

    reg start_merging= 0;

    always_ff @(posedge clock) begin
        if(~reset) begin
        end else begin
            case (sorter_state)
                idle_sorter: begin
                    if(start) begin
                        shadow_data_length <= data_length;
                        n_complete_chunks <= data_length/8;
                        last_chunk_size <= data_length%8;
                        sorter_state <= wait_transfer_start;
                        current_chunk <= 0;
                    end
                end
                wait_transfer_start: begin
                    if(transfer_start) begin
                        transfer_index <=0; 
                        if(current_chunk == n_complete_chunks && last_chunk_size != 0)begin
                            sorter_state <= read_last_chunk;
                        end else begin
                            sorter_state <= read_full_chunk;
                        end
                    end

                end
                read_full_chunk: begin
 
                    if(transfer_index == 7) begin
                        sorter_state <= wait_transfer_start;
                        current_chunk <= current_chunk + 1;
                    end

                    mem_a_addr_w <= sort_buffer_level;
                    mem_a_data_w <= transfer_buffer[transfer_index];

                    transfer_index <= transfer_index + 1;
                    sort_buffer_level <= sort_buffer_level  + 1;

                    if(sort_buffer_level == shadow_data_length-1) begin
                        sorter_state <= wait_merge_unit;
                    end
                end 
                read_last_chunk: begin
                    sort_buffer_level <= sort_buffer_level  + 1;
                    
                    mem_a_addr_w <= sort_buffer_level;
                    mem_a_data_w <= transfer_buffer[ transfer_index + (8 - last_chunk_size)];  // skip initial zero padding
                    
                    transfer_index <= transfer_index + 1;
                    sort_buffer_level <= sort_buffer_level  + 1;

                    if(sort_buffer_level == shadow_data_length-1) begin
                        sorter_state <= wait_merge_unit;
                        start_merging <= 1;
                    end 
                end
                wait_merge_unit: begin
                    start_merging <= 0;
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