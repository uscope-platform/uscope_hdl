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
//`include "interfaces.svh"



module prioritised_fifo #(parameter INPUT_DATA_WIDTH = 32, parameter FIFO_DEPTH = 16)(
    input wire clock,
    input wire reset,
    input wire [INPUT_DATA_WIDTH-1:0]data_in_lp,
    input wire data_in_lp_valid,
    input wire data_in_lp_tlast,
    output reg data_in_lp_ready,
    input wire [INPUT_DATA_WIDTH-1:0]data_in_hp,
    input wire data_in_hp_valid,
    input wire data_in_hp_tlast,
    output reg data_in_hp_ready,
    output reg [INPUT_DATA_WIDTH-1:0]data_out,
    output reg data_out_valid,
    output reg data_out_tlast,
    input wire data_out_ready
);



    reg [INPUT_DATA_WIDTH-1:0] lp_memory_in;
    reg [INPUT_DATA_WIDTH-1:0] hp_memory_in;
    wire [INPUT_DATA_WIDTH-1:0] lp_memory_out;
    wire [INPUT_DATA_WIDTH-1:0] hp_memory_out;

    reg [$clog2(FIFO_DEPTH)-1:0] hp_mem_addr_w;
    reg [$clog2(FIFO_DEPTH)-1:0] lp_mem_addr_w;
    reg [$clog2(FIFO_DEPTH)-1:0] hp_mem_addr_r;
    reg [$clog2(FIFO_DEPTH)-1:0] lp_mem_addr_r;

    reg [$clog2(FIFO_DEPTH):0] hp_fill_level;
    reg [$clog2(FIFO_DEPTH):0] lp_fill_level;

    reg lp_we, hp_we;
    reg hp_last_in, lp_last_in;
    wire hp_last_out, lp_last_out;

    dual_read_register_file #(
        .DATA_WIDTH(INPUT_DATA_WIDTH+1),
        .ADDR_WIDTH($clog2(FIFO_DEPTH))
    ) hp_memory(
        .clk(clock),
        .reset(reset),
        .data_a({hp_last_in ,hp_memory_in}),
        .addr_a(hp_mem_addr_w),
        .addr_b(hp_mem_addr_r),
        .we_a(hp_we),
        .q_b({hp_last_out,hp_memory_out})
    );

    dual_read_register_file #(
        .DATA_WIDTH(INPUT_DATA_WIDTH+1),
        .ADDR_WIDTH($clog2(FIFO_DEPTH))
    ) lp_memory(
        .clk(clock),
        .reset(reset),
        .data_a({lp_last_in,lp_memory_in}),
        .addr_a(lp_mem_addr_w),
        .addr_b(lp_mem_addr_r),
        .we_a(lp_we),
        .q_b({lp_last_out,lp_memory_out})
    );

    always@(posedge clock) begin
        if(~reset)begin
            lp_fill_level <=0;
            hp_fill_level <=0;
            hp_mem_addr_w <=0;
            lp_mem_addr_w <=0;
            hp_mem_addr_r <=0;
            lp_mem_addr_r <=0;
            lp_memory_in <=0;
            hp_memory_in <=0;
            hp_we <=0;
            lp_we <=0;
            data_out <= 0;
            data_out_valid <=0;
        end else begin
            if(data_out_valid) data_out_valid <= 0;
            if(data_out_tlast) data_out_tlast <= 0;
            else if(data_out_ready)begin
                if(hp_fill_level != 0)begin
                    hp_mem_addr_r <= hp_mem_addr_r+1;
                    data_out <= hp_memory_out;
                    data_out_tlast <= hp_last_out;
                    data_out_valid <=1;
                    hp_fill_level<= hp_fill_level-1;
                end else if(lp_fill_level != 0) begin
                    lp_mem_addr_r <= lp_mem_addr_r+1;
                    data_out <= lp_memory_out;
                    data_out_tlast <= lp_last_out;
                    data_out_valid <=1;
                    lp_fill_level<= lp_fill_level-1;
                end
            end
            if(data_in_hp_valid)begin
                hp_memory_in <= data_in_hp;
                hp_last_in <= data_in_hp_tlast;
                hp_we <= 1;
                hp_fill_level<= hp_fill_level+1;
            end

            if(hp_we) begin
                hp_we <= 0;
                hp_mem_addr_w <= hp_mem_addr_w+1;
            end

            if(data_in_lp_valid)begin
                lp_memory_in <= data_in_lp;
                lp_last_in <= data_in_lp_tlast;
                lp_we <= 1;
                lp_fill_level<= lp_fill_level+1;
            end

            if(lp_we) begin
                lp_mem_addr_w <= lp_mem_addr_w+1;  
                lp_we <= 0;
            end
        end
    end


    always@(*)begin
        if(hp_fill_level==FIFO_DEPTH) data_in_hp_ready <=0;
        else data_in_hp_ready <=1;
        
        if(lp_fill_level==FIFO_DEPTH) data_in_lp_ready <=0;
        else data_in_lp_ready <=1;
    end



endmodule