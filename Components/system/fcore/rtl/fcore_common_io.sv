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
    output reg [31:0] read_data_a,
    output reg [31:0] read_data_b
);


    reg [$clog2(N_IO)-1:0] address_fifo [FIFO_DEPTH-1:0] = '{default:0};
    reg [31:0] data_fifo [FIFO_DEPTH-1:0] = '{default:0};


    reg [31:0] common_io_memory [N_IO-1:0] = '{default:0};


    reg [$clog2(FIFO_DEPTH)-1:0] fifo_counter = 0; 
    reg [$clog2(FIFO_DEPTH)-1:0] unload_target = 0; 


    enum reg[1:0] { 
        dma_enabled = 0,
        core_running = 1,
        fifo_unloading = 2
    } state = dma_enabled;

    always_ff @( posedge clock ) begin
        case(state)
        dma_enabled: begin
            if(core_start) begin
                fifo_counter <= 0;
                state <= core_running;
            end
        end
        core_running: begin
            if(dma_in.valid) fifo_counter <= fifo_counter + 1;
            if(core_done)begin
                state <= fifo_unloading;
                unload_target <= fifo_counter;
                fifo_counter <= 0;
                dma_in.ready <= 0;
            end
        end
        fifo_unloading: begin
            fifo_counter <= fifo_counter + 1;
            if(fifo_counter == unload_target)begin
                state <= dma_enabled;
                dma_in.ready <= 1;
            end
        end
        endcase
    end

    always_ff @(posedge clock)begin

        read_data_a <= common_io_memory[read_address_a];
        read_data_b <= common_io_memory[read_address_b];
        
        if(dma_in.valid)begin
            if(state == dma_enabled) begin
                common_io_memory[dma_in.dest] <= dma_in.data;
            end else if(state == core_running)begin
                address_fifo[fifo_counter] <= dma_in.dest;
                data_fifo[fifo_counter] <= dma_in.data;
            end 
        end

        if(state == fifo_unloading)begin
            common_io_memory[address_fifo[fifo_counter]] <= data_fifo[fifo_counter];
        end
    end
    
endmodule
