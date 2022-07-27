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


module merging_unit #(
    parameter DATA_WIDTH=32,
    parameter MAX_SORT_LENGTH=32,
    parameter BASE_CHUNK_SIZE=8
)(
    input wire clock,
    input wire reset,
    axi_stream.slave data_in,
    input wire [$clog2(MAX_SORT_LENGTH/8-1):0] n_chunks_in,
    input wire [$clog2(BASE_CHUNK_SIZE)-1:0] last_chunk_size,
    axi_stream.master data_out
);

    reg [$clog2(MAX_SORT_LENGTH)-1:0] buffer_fill;

    always_ff @(posedge clock) begin
            buffer_fill <= 0;
        if(data_in.valid)begin
            buffer_fill <= buffer_fill + 1;
        end
    end


    wire [$clog2(MAX_SORT_LENGTH)-1:0] mem_1_addr_a;
    wire [DATA_WIDTH-1:0] mem_1_data_a_w;
    wire [DATA_WIDTH-1:0] mem_1_data_a_r;
    wire mem_1_we_a;

    wire [$clog2(MAX_SORT_LENGTH)-1:0] mem_1_addr_b;
    reg [DATA_WIDTH-1:0] mem_1_data_b_r;

    reg writeback_enable;

    wire [15:0] mf1_addr;
    wire [15:0] mf3_addr;
    wire [15:0] mf3_data;
    reg [15:0] mf2_addr;

    
    assign mem_1_addr_a = data_in.valid ? buffer_fill : mf1_addr | mf3_addr;
    assign mem_1_addr_b = mf2_addr;
    assign mem_1_data_a_w = data_in.valid ? data_in.data : mf3_data; 
    assign mem_1_we_a = data_in.valid | writeback_enable;


    true_dp_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH($clog2(MAX_SORT_LENGTH))
    ) working_mem_1 (
        .clock(clock),
        .addr_a(mem_1_addr_a),
        .data_a_w(mem_1_data_a_w),
        .data_a_r(mem_1_data_a_r),
        .we_a(mem_1_we_a),    
        .addr_b(mem_1_addr_b),
        .data_b_r(mem_1_data_b_r),
        .we_b(0)
    );



    axi_stream #(.DATA_WIDTH(DATA_WIDTH)) chunk_a_stream();
    axi_stream #(.DATA_WIDTH(DATA_WIDTH)) chunk_b_stream();

    reg[15:0] mf1_size;
    reg[15:0] mf1_chunk_base = 0;

    reg merge_read_start = 0;
    reg mf1_done, mf2_done;
    merger_input_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_SORT_LENGTH(MAX_SORT_LENGTH)
    )mf1(
        .clock(clock),
        .reset(reset),
        .start(merge_read_start),
        .chunk_size(mf1_size),
        .chunk_base_address(mf1_chunk_base),
        .read_data(mem_1_data_a_r),
        .output_data(chunk_a_stream),
        .read_addr(mf1_addr),
        .done(mf1_done)
    );

    reg[15:0] mf2_size;
    reg[15:0] mf2_chunk_base = 0;

    merger_input_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_SORT_LENGTH(MAX_SORT_LENGTH)
    )mf2(
        .clock(clock),
        .reset(reset),
        .start(merge_read_start),
        .chunk_size(mf2_size),
        .chunk_base_address(mf2_chunk_base),
        .read_data(mem_1_data_b_r),
        .output_data(chunk_b_stream),
        .read_addr(mf2_addr),
        .done(mf2_done)
    );
    wire merge_done;
    axi_stream #(.DATA_WIDTH(DATA_WIDTH)) merged_stream();  
    merging_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_SORT_LENGTH(MAX_SORT_LENGTH)
     ) merge_core (
        .clock(clock),
        .chunk_a_size(mf1_size),
        .chunk_b_size(mf2_size),
        .stream_in_a(chunk_a_stream),
        .stream_in_b(chunk_b_stream),
        .merged_stream(merged_stream),
        .merge_done(merge_done)
    );

    reg mf3_start, writeback_done;
    reg[15:0] result_chunk_size;
    reg selected_stream;

    axi_stream #(.DATA_WIDTH(DATA_WIDTH)) writeback_stream();  
    axi_stream_selector_2 out_selector(
        .clock(clock),
        .address(selected_stream),
        .stream_in(merged_stream),
        .stream_out_1(writeback_stream), 
        .stream_out_2(data_out)
    );

    merger_output_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_SORT_LENGTH(MAX_SORT_LENGTH)
    ) mf3 (
        .clock(clock),
        .reset(reset),
        .start(mf3_start),
        .chunk_size(result_chunk_size),
        .input_data(writeback_stream),
        .write_data(mf3_data),
        .write_addr(mf3_addr),
        .write_enable(writeback_enable),
        .writeback_done(writeback_done)
    );

    reg[15:0] chunks_to_merge  = 0;

    reg latched_mf1_done = 0;
    reg latched_mf2_done = 0;

    enum logic [2:0] {
        fsm_idle = 0,
        fsm_reading = 1,
        fsm_merging = 2,
        fsm_writeback = 3
    } fsm_merger = fsm_idle;

    always_ff @(posedge clock)begin

        case(fsm_merger)
        fsm_idle:begin
            merge_read_start <= 0;
            mf3_start <= 0;
            if(data_in.tlast)begin
                fsm_merger <= fsm_reading;
                mf1_chunk_base <= 0;
                mf1_size <= BASE_CHUNK_SIZE;
                mf2_chunk_base <= BASE_CHUNK_SIZE;    
                result_chunk_size <= 2*BASE_CHUNK_SIZE;
                mf2_size <= BASE_CHUNK_SIZE;
                merge_read_start <= 1;

                if(last_chunk_size == 0)begin
                    chunks_to_merge <= n_chunks_in-2;
                end else begin
                    chunks_to_merge <= n_chunks_in-2+1;
                end
            end
        end
        fsm_reading:begin
            merge_read_start<= 0;
            if(merged_stream.valid)begin
                fsm_merger <= fsm_merging;
            end
        end
        fsm_merging:begin
            if(merge_done)begin
                if(chunks_to_merge == 0) begin
                    fsm_merger <= fsm_idle;
                end else begin
                    mf3_start <= 1;
                    fsm_merger <= fsm_writeback;
                end
            end
        end
        fsm_writeback:begin
            mf3_start <= 0;
            if(writeback_done)begin
                    chunks_to_merge <= chunks_to_merge-1;
                    fsm_merger <= fsm_reading;
                    mf1_size <= result_chunk_size;
                    mf2_chunk_base <= result_chunk_size;
                    merge_read_start <= 1;
                if(chunks_to_merge == 1 & last_chunk_size != 0)begin
                    mf2_size <= last_chunk_size;
                    result_chunk_size <= result_chunk_size+last_chunk_size;
                end else begin
                    result_chunk_size <= result_chunk_size+BASE_CHUNK_SIZE;
                end
            end

        end
        endcase
    end

    always_comb begin 
        if(merged_stream.valid & chunks_to_merge == 0)begin
            selected_stream <= 1;
        end else begin
            selected_stream <= 0;
        end
    end


endmodule