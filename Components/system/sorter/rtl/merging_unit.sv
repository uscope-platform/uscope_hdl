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
    parameter DEST_WIDTH=32,
    parameter USER_WIDTH=32,
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

    axi_stream #(.DATA_WIDTH(DATA_WIDTH), .DEST_WIDTH(DEST_WIDTH), .USER_WIDTH(USER_WIDTH)) registered_input();
    axi_stream #(.DATA_WIDTH(DATA_WIDTH), .DEST_WIDTH(DEST_WIDTH), .USER_WIDTH(USER_WIDTH)) bypass_load();
    axi_stream #(.DATA_WIDTH(DATA_WIDTH), .DEST_WIDTH(DEST_WIDTH), .USER_WIDTH(USER_WIDTH)) stream_to_merge();
    axi_stream #(.DATA_WIDTH(DATA_WIDTH), .DEST_WIDTH(DEST_WIDTH), .USER_WIDTH(USER_WIDTH)) merge_result();
    axi_stream #(.DATA_WIDTH(DATA_WIDTH), .DEST_WIDTH(DEST_WIDTH), .USER_WIDTH(USER_WIDTH)) result_fifo_in();
    axi_stream #(.DATA_WIDTH(DATA_WIDTH), .DEST_WIDTH(DEST_WIDTH), .USER_WIDTH(USER_WIDTH)) post_out_result();
    axi_stream #(.DATA_WIDTH(DATA_WIDTH), .DEST_WIDTH(DEST_WIDTH), .USER_WIDTH(USER_WIDTH)) merger_feedback();

    reg select_merge_bypass, output_selector, core_start;
    wire merge_done;


    reg [15:0] input_chunk_size;
    reg [15:0] result_size;


    axis_fifo_xpm #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEST_WIDTH(DEST_WIDTH),
        .USER_WIDTH(USER_WIDTH),
        .FIFO_DEPTH(MAX_SORT_LENGTH)
    ) input_fifo (
        .clock(clock),
        .reset(reset),
        .in(data_in),
        .out(registered_input)
    );


    axi_stream_selector_2 #(
        .REGISTERED(0)
    ) bypass_selector(
        .clock(clock),
        .address(select_merge_bypass),
        .stream_in(registered_input),
        .stream_out_1(stream_to_merge), 
        .stream_out_2(bypass_load)
    );


    merging_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEST_WIDTH(DEST_WIDTH),
        .USER_WIDTH(USER_WIDTH),
        .MAX_SORT_LENGTH(MAX_SORT_LENGTH)
     ) merge_core (
        .clock(clock),
        .start(core_start),
        .chunk_a_size(result_size),
        .chunk_b_size(input_chunk_size),
        .stream_in_a(merger_feedback),
        .stream_in_b(stream_to_merge),
        .merged_stream(merge_result),
        .merge_done(merge_done)
    );


    axi_stream_selector_2 #(
        .REGISTERED(0)
    ) result_selector(
        .clock(clock),
        .address(output_selector),
        .stream_in(merge_result),
        .stream_out_1(post_out_result), 
        .stream_out_2(data_out)
    );
    


    axi_stream_mux_2 #(
        .DATA_WIDTH(DATA_WIDTH)
    )result_mux(
        .clock(clock),
        .reset(reset),
        .address(select_merge_bypass),
        .stream_in_1(post_out_result),
        .stream_in_2(bypass_load),
        .stream_out(result_fifo_in)
    );


    axis_fifo_xpm #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEST_WIDTH(DEST_WIDTH),
        .USER_WIDTH(USER_WIDTH),
        .FIFO_DEPTH(MAX_SORT_LENGTH)
    ) result_fifo (
        .clock(clock),
        .reset(reset),
        .in(result_fifo_in),
        .out(merger_feedback)
    );


    reg [2:0] start_merging_pipe;


    reg[15:0] chunks_to_merge  = 0;

    enum logic [2:0] {
        fsm_idle = 0,
        fsm_bypass = 1,
        fsm_merging = 2,
        fsm_update_sizes = 3,
        fsm_done = 4
    } fsm_merger = fsm_idle;

    reg [2:0] bypass_load_ctr;

    always_ff @(posedge clock)begin
        case(fsm_merger)
        fsm_idle:begin
        bypass_load_ctr <=1;
        output_selector <= 0;
        select_merge_bypass <= 1;
        start_merging_pipe[0] <= data_in.valid;
        start_merging_pipe[1] <= start_merging_pipe[0];
        start_merging_pipe[2] <= start_merging_pipe[1];
        core_start <= 0;
        if(start_merging_pipe[2])begin
            input_chunk_size <= 8;
            result_size <= 8;
            fsm_merger <= fsm_bypass;
            if(last_chunk_size != 0)begin
                    if(n_chunks_in == 1) begin
                        input_chunk_size <= last_chunk_size;
                    end else if (n_chunks_in == 0) begin
                        input_chunk_size <= last_chunk_size;
                        result_size <= last_chunk_size;
                    end
                chunks_to_merge <= n_chunks_in;
            end else begin
                chunks_to_merge <= n_chunks_in-1;
            end
        end
        end
        fsm_bypass:begin
            if(bypass_load_ctr == 7)begin 
                select_merge_bypass <= 0;
                core_start <= 1;
                fsm_merger <= fsm_merging;
            end else begin
                bypass_load_ctr <= bypass_load_ctr + 1;
            end
        end
        fsm_merging:begin
            core_start <= 0;
            if(chunks_to_merge == 1)begin
                output_selector <= 1;
            end
            if(merge_done) begin
                fsm_merger <= fsm_update_sizes;
                chunks_to_merge <= chunks_to_merge-1;
            end  
        end
        fsm_update_sizes:begin
            if(chunks_to_merge == 1) begin
                if(last_chunk_size != 0)begin
                    input_chunk_size <= last_chunk_size;
                end
            end
            result_size <= result_size + BASE_CHUNK_SIZE;
            

            if(chunks_to_merge == 0)begin
                fsm_merger <= fsm_idle;
            end else begin
                core_start <= 1;
                fsm_merger <= fsm_merging;
            end
        end
        endcase
    end

endmodule