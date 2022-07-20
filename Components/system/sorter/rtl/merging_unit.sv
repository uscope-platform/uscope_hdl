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
    input wire [DATA_WIDTH-1:0] input_data,
    input wire [$clog2(MAX_SORT_LENGTH)-1:0] input_addr,
    input wire start_merging
);

    reg select_input_mem = 0;

    wire [$clog2(MAX_SORT_LENGTH)-1:0] mem_a_addr_w;
    wire [DATA_WIDTH-1:0] mem_a_data_w;

    assign mem_a_addr_w = select_input_mem ? 0 : input_addr;
    assign mem_a_data_w = select_input_mem ? 0 : input_data;


    reg [$clog2(MAX_SORT_LENGTH)-1:0] mem_a_addr_r;
    reg [DATA_WIDTH-1:0] mem_a_data_r;

    reg [$clog2(MAX_SORT_LENGTH)-1:0] mem_b_addr_w;
    reg [$clog2(MAX_SORT_LENGTH)-1:0] mem_b_addr_r;
    reg [DATA_WIDTH-1:0] mem_b_data_w;
    reg [DATA_WIDTH-1:0] mem_b_data_r;


    DP_RAM#(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH($clog2(MAX_SORT_LENGTH))
    ) sort_mem_a (
        .clk(clock),
        .addr_a(mem_a_addr_w),
        .data_a(mem_a_data_w),
        .we_a(1'b1),    
        .addr_b(mem_a_addr_r),
        .data_b(mem_a_data_r),
        .en_b(1'b1)
    );

    DP_RAM#(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH($clog2(MAX_SORT_LENGTH))
    ) sort_mem_b (
        .clk(clock),
        .addr_a(mem_b_addr_w),
        .data_a(mem_b_addr_r),
        .we_a(1'b1),    
        .addr_b(mem_b_data_w),
        .data_b(mem_b_data_r),
        .en_b(1'b1)
    );



endmodule