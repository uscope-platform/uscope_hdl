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

module fCore_common_io #(
    parameter REGISTER_WIDTH = 32,
    N_IO = 32,
    FIFO_DEPTH = 16
)(
    input wire clock,
    input wire reset,
    input wire core_start,
    input wire core_done,
    axi_stream dma_in,
    input wire [$clog2(N_IO)-1:0] read_address_a,
    input wire [$clog2(N_IO)-1:0] read_address_b,
    input wire [$clog2(N_IO)-1:0] read_address_c,
    output reg [31:0] read_data_a,
    output reg [31:0] read_data_b,
    output reg [31:0] read_data_c
);

    axi_stream in_buffered();

    axis_fifo_xpm #(
        .DATA_WIDTH(32),
        .DEST_WIDTH(32),
        .FIFO_DEPTH(16),
        .SIM_ASSERT_CHK(0)
    )fifo_in(
        .clock(clock),
        .reset(reset),
        .in(dma_in),
        .out(in_buffered)
    );

    reg [31:0] common_io_memory [N_IO-1:0] = '{default:0};

    enum reg[1:0] { 
        dma_enabled = 0,
        core_running = 1
    } state = dma_enabled;

    always_ff @( posedge clock ) begin
        case(state)
        dma_enabled: begin
            in_buffered.ready <= 1;
            if(core_start) begin
                state <= core_running;
                in_buffered.ready <= 0;
            end
        end
        core_running: begin
            if(core_done)begin
                state <= dma_enabled;
                in_buffered.ready <= 1;
            end
        end
        endcase
    end

    always_ff @(posedge clock)begin

        read_data_a <= common_io_memory[read_address_a];
        read_data_b <= common_io_memory[read_address_b];
        read_data_c <= common_io_memory[read_address_c];
        
        if(in_buffered.valid & in_buffered.ready)begin
           common_io_memory[in_buffered.dest] <= in_buffered.data;
        end
    end
    
endmodule
