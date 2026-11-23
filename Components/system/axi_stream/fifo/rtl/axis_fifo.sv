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

module axis_fifo #(parameter DATA_WIDTH = 32,USER_WIDTH = 32, DEST_WIDTH = 32, FIFO_DEPTH = 16)(
    input wire clock,
    input wire reset,
    axi_stream.slave in,
    axi_stream.master out
);


reg [$clog2(FIFO_DEPTH)-1:0] hp_mem_addr_w;
reg [$clog2(FIFO_DEPTH)-1:0] hp_mem_addr_r;

reg [$clog2(FIFO_DEPTH):0] fill_level;

reg [DATA_WIDTH:0] fifo_memory[FIFO_DEPTH-1:0];
reg [DEST_WIDTH-1:0] dest_memory[FIFO_DEPTH-1:0];
reg [USER_WIDTH-1:0] user_memory[FIFO_DEPTH-1:0];
integer i;

// a beat enters the memory / moves from the memory to the output register in this cycle
wire push = in.valid && in.ready;
wire out_held = out.valid && ~out.ready;  // a beat is waiting at the output and has not been taken
wire pop = ~out_held && fill_level != 0;
// the memory is empty and the output is free, so the input beat goes straight to the output register, order is kept
wire bypass = push && ~out_held && fill_level == 0;
wire store = push && ~bypass;

always@(posedge clock) begin
    if(~reset)begin
        for(i = 0; i< FIFO_DEPTH; i = i+1)begin
            fifo_memory[i] = 0;
        end
        for(i = 0; i< FIFO_DEPTH; i = i+1)begin
            dest_memory[i] = 0;
        end 
        for(i = 0; i< FIFO_DEPTH; i = i+1)begin
            user_memory[i] = 0;
        end 
        fill_level <=0;
        hp_mem_addr_w <=0;
        hp_mem_addr_r <=0;
        out.data <= 0;
        out.valid <= 0;
        out.tlast <= 0;
    end else begin
        // WRITE: a beat is accepted when the handshake on the input completes
        if(store)begin
            fifo_memory[hp_mem_addr_w] <= {in.tlast, in.data};
            dest_memory[hp_mem_addr_w] <= in.dest;
            user_memory[hp_mem_addr_w] <= in.user;
            if(hp_mem_addr_w == FIFO_DEPTH-1) hp_mem_addr_w <= 0;
            else hp_mem_addr_w <= hp_mem_addr_w+1;
        end

        // READ: the output register is reloaded when it is empty or its beat is being taken
        if(out.valid && out.ready) out.valid <= 0;
        if(pop)begin
            {out.tlast,out.data[DATA_WIDTH-1:0]} <= fifo_memory[hp_mem_addr_r];
            out.dest <= dest_memory[hp_mem_addr_r];
            out.user <= user_memory[hp_mem_addr_r];
            out.valid <= 1;
            if(hp_mem_addr_r == FIFO_DEPTH-1) hp_mem_addr_r <= 0;
            else hp_mem_addr_r <= hp_mem_addr_r+1;
        end else if(bypass)begin
            {out.tlast,out.data} <= {in.tlast, in.data};
            out.dest <= in.dest;
            out.user <= in.user;
            out.valid <= 1;
        end

        if(store && ~pop) fill_level <= fill_level+1;
        else if(pop && ~store) fill_level <= fill_level-1;
    end
end

always_comb begin
    if(fill_level==FIFO_DEPTH) in.ready =0;
    else in.ready =1;
end

endmodule