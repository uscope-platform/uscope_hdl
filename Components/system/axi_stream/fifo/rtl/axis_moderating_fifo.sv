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

module axis_moderating_fifo #(parameter DATA_WIDTH = 32,USER_WIDTH = 32, DEST_WIDTH = 32, FIFO_DEPTH = 16)(
    input wire clock,
    input wire reset,
    axi_stream.slave in,
    axi_stream.master out
);


    reg [$clog2(FIFO_DEPTH)-1:0] mem_addr_w = 0;
    reg [$clog2(FIFO_DEPTH)-1:0] mem_addr_r = 0;

    reg [DATA_WIDTH-1:0] fifo_memory[FIFO_DEPTH-1:0] = '{default:0};
    reg [DEST_WIDTH-1:0] dest_memory[FIFO_DEPTH-1:0] = '{default:0};
    reg [USER_WIDTH-1:0] user_memory[FIFO_DEPTH-1:0] = '{default:0};
    reg [FIFO_DEPTH-1:0] tlast_memory = 0;

    initial begin
        out.data <= 0;
        out.valid <= 0;
        out.tlast <= 0;
    end

   enum reg [1:0] {
        fill = 0,
        empty = 1
   } phase = fill;

    assign in.ready = phase == fill;

    always_ff @( posedge clock ) begin 
        out.valid <= 0;
        out.tlast <= 0;
        case (phase)
            fill:begin
                if(in.valid)begin
                    mem_addr_r <= 0;
                    fifo_memory[mem_addr_w] <= in.data;
                    dest_memory[mem_addr_w] <= in.dest;
                    user_memory[mem_addr_w] <= in.user;
                    tlast_memory[mem_addr_w] <= in.tlast;

                    mem_addr_w <= mem_addr_w+1;
                end
                if(mem_addr_w==7)begin
                    phase <= empty;
                end
            end
            empty:begin
                mem_addr_w <= 0;
                out.valid <=1;
                if(out.valid & out.ready)begin
                    mem_addr_r <= mem_addr_r+1;
                end
                if(mem_addr_r==7)begin
                    phase <= fill;
                end
            end 
        endcase
    end


    assign out.data = fifo_memory[mem_addr_r];
    assign out.dest = dest_memory[mem_addr_r];
    assign out.user = user_memory[mem_addr_r];
    assign out.tlast = tlast_memory[mem_addr_r];

endmodule