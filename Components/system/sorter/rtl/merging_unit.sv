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

    reg writeback_enable = 0;

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
    wire [15:0] mf1_addr;
    reg[15:0] mf1_chunk_base = 0;

    reg merge_read_start = 0;
    
    merger_input_fifo #(
        .DATA_WIDTH(32),
        .MAX_SORT_LENGTH(32)
    )mf1(
        .clock(clock),
        .reset(reset),
        .start(merge_read_start),
        .chunk_size(mf1_size),
        .chunk_base_address(mf1_chunk_base),
        .read_data(mem_1_data_a_r),
        .output_data(chunk_a_stream),
        .read_addr(mf1_addr)
    );

    reg[15:0] mf2_size;
    reg[15:0] mf2_addr;
    reg[15:0] mf2_chunk_base = 0;

    merger_input_fifo #(
        .DATA_WIDTH(32),
        .MAX_SORT_LENGTH(32)
    )mf2(
        .clock(clock),
        .reset(reset),
        .start(merge_read_start),
        .chunk_size(mf2_size),
        .chunk_base_address(mf2_chunk_base),
        .read_data(mem_1_data_b_r),
        .output_data(chunk_b_stream),
        .read_addr(mf2_addr)
    );

    axi_stream #(.DATA_WIDTH(DATA_WIDTH)) merged_stream();  
    merging_core #(
        .DATA_WIDTH(DATA_WIDTH)
     ) merge_core (
        .clock(clock),
        .reset(reset),
        .stream_in_a(chunk_a_stream),
        .stream_in_b(chunk_b_stream),
        .merged_stream(merged_stream)
    );

    reg mf3_start, writeback_done;
    reg[15:0] result_chunk_size;
    wire [15:0] mf3_addr;
    wire [15:0] mf3_data;


    merger_output_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_SORT_LENGTH(MAX_SORT_LENGTH)
    ) mf3 (
        .clock(clock),
        .reset(reset),
        .start(mf3_start),
        .chunk_size(result_chunk_size),
        .input_data(merged_stream),
        .write_data(mf3_data),
        .write_addr(mf3_addr),
        .write_enable(writeback_enable),
        .writeback_done(writeback_done)
    );

    reg[15:0] chunks_to_merge  = 0;

    enum logic [2:0] {
        fsm_idle = 0,
        fsm_reading = 1,
        fsm_merging = 2,
        fsm_writeback = 3,
        fsm_read_last_chunk = 4,
        fsm_merge_last_chunk = 5,
        fsm_write_last_chunk = 6
    } fsm_merger = fsm_idle;

    always_ff @(posedge clock)begin
        case(fsm_merger)
        fsm_idle:begin
            merge_read_start <= 0;
            mf3_start <= 0;
            if(data_in.tlast)begin
                chunks_to_merge <= n_chunks_in-2;
                fsm_merger <= fsm_reading;
                mf1_chunk_base <= 0;
                mf1_size <= BASE_CHUNK_SIZE;
                mf2_chunk_base <= BASE_CHUNK_SIZE;    
                result_chunk_size <= 2*BASE_CHUNK_SIZE;
                mf2_size <= BASE_CHUNK_SIZE;
                merge_read_start <= 1;
            end
        end
        fsm_reading:begin
            merge_read_start<= 0;
            if(merged_stream.valid)begin
                fsm_merger <= fsm_merging;
            end
        end
        fsm_merging:begin
            if(~merged_stream.valid)begin
                fsm_merger <= fsm_writeback;
                mf3_start <= 1;
            end
        end
        fsm_writeback:begin
            mf3_start <= 0;
            if(writeback_done)begin
                if(chunks_to_merge == 0)begin
                    if(last_chunk_size != 0)begin
                        fsm_merger <= fsm_read_last_chunk;
                        mf1_size <= result_chunk_size;
                        mf2_chunk_base <= result_chunk_size;
                        mf2_size <= last_chunk_size;
                        merge_read_start <= 1;
                        result_chunk_size <= result_chunk_size+last_chunk_size;

                    end else begin
                        fsm_merger <= fsm_idle;
                    end
                end else begin
                    mf1_size <= result_chunk_size;
                    mf2_chunk_base <= result_chunk_size;
                    chunks_to_merge <= chunks_to_merge-1;
                    merge_read_start <= 1;
                    result_chunk_size <= result_chunk_size+BASE_CHUNK_SIZE;
                    fsm_merger <= fsm_reading;
                end
            end

        end
        fsm_read_last_chunk: begin
            merge_read_start<= 0;
            if(merged_stream.valid)begin
                fsm_merger <= fsm_merge_last_chunk;
            end
        end

        fsm_merge_last_chunk:begin
            if(~merged_stream.valid)begin
                fsm_merger <= fsm_write_last_chunk;
                mf3_start <= 1;
            end
        end
        
        fsm_write_last_chunk: begin
            if(writeback_done)begin
                fsm_merger <= fsm_idle;
            end
            mf3_start <= 0;
        end
        endcase
    end

    always_comb begin 
        if(fsm_merger == fsm_read_last_chunk)begin
            data_out.data <= mf3_data;
            data_out.valid <= 1;
        end else begin
            data_out.valid <= 0;
        end
    end


endmodule