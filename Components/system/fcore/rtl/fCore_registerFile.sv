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
`include "interfaces.svh"

module fCore_registerFile #(parameter REGISTER_WIDTH = 32, FILE_DEPTH = 12, REG_PER_CHANNEL = 16)(
    input wire clock,
    input wire reset,

    axi_stream.slave write_if,
    
    input wire dma_enable,
    
    input wire [$clog2(FILE_DEPTH)-1:0] read_addr_a,
    output reg [REGISTER_WIDTH-1:0] read_data_a,
    input wire [$clog2(FILE_DEPTH)-1:0] read_addr_b,
    output reg [REGISTER_WIDTH-1:0] read_data_b,
    input wire [$clog2(FILE_DEPTH)-1:0] dma_read_addr,
    output reg [REGISTER_WIDTH-1:0] dma_read_data,
    axi_stream.slave dma_write
    );





    reg [REGISTER_WIDTH-1:0] ram_a_read_data;
    reg [$clog2(FILE_DEPTH)-1:0] ram_a_read_addr;
    reg [REGISTER_WIDTH-1:0] ram_b_read_data;
    reg [$clog2(FILE_DEPTH)-1:0] ram_b_read_addr;

    axi_stream #(
        .DATA_WIDTH(REGISTER_WIDTH),
        .DEST_WIDTH($clog2(FILE_DEPTH))
    ) ram_write_if();


    DP_RAM#(
        .DATA_WIDTH(REGISTER_WIDTH),
        .ADDR_WIDTH($clog2(FILE_DEPTH))
    ) mem_a (
        .clk(clock),
        .data_a(ram_write_if.data),
        .data_b(ram_a_read_data),
        .addr_a(ram_write_if.dest),
        .addr_b(ram_a_read_addr),
        .we_a(ram_write_if.valid),
        .en_b(1'b1)
    );


    DP_RAM#(
        .DATA_WIDTH(REGISTER_WIDTH),
        .ADDR_WIDTH($clog2(FILE_DEPTH))
    ) mem_b (
        .clk(clock),
        .data_a(ram_write_if.data),
        .data_b(ram_b_read_data),
        .addr_a(ram_write_if.dest),
        .addr_b(ram_b_read_addr),
        .we_a(ram_write_if.valid),
        .en_b(1'b1)
    );

    
    always_comb begin
        if(dma_enable) begin
            ram_write_if.data <= dma_write.data;
            ram_write_if.dest <= dma_write.dest;
            ram_write_if.valid <= dma_write.valid;
            ram_a_read_addr <= dma_read_addr;
            ram_b_read_addr <= dma_read_addr;
            dma_read_data <= ram_a_read_data;
            read_data_a <= 0;
            read_data_b <= 0;
        end else begin
            if(write_if.dest % REG_PER_CHANNEL != 0)begin
                ram_write_if.data <= write_if.data;
            end else begin
                ram_write_if.data <= 0;
            end
            ram_write_if.dest <= write_if.dest;
            ram_write_if.valid <= write_if.valid;
            ram_a_read_addr <= read_addr_a;
            ram_b_read_addr <= read_addr_b;
            dma_read_data <= 0;
            read_data_a <= ram_a_read_data;
            read_data_b <= ram_b_read_data;
        end
    end
    
endmodule
