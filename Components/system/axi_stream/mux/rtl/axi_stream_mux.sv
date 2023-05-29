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

module axi_stream_mux #(
    parameter N_STREAMS = 2,
    DATA_WIDTH = 32, 
    DEST_WIDTH = 8, 
    USER_WIDTH = 8,
    BUFFERED = 1
)(
    input wire clock,
    input wire reset,
    input wire [$clog2(N_STREAMS)-1:0] address,
    axi_stream.slave stream_in[N_STREAMS],
    axi_stream.master stream_out
);


    wire [N_STREAMS-1:0]valid_bus;
    wire [N_STREAMS-1:0] unrolled_tlast;
    wire [DEST_WIDTH-1:0] unrolled_dest [N_STREAMS-1:0];
    wire [USER_WIDTH-1:0] unrolled_user [N_STREAMS-1:0];
    wire [DATA_WIDTH-1:0] unrolled_data [N_STREAMS-1:0];

    genvar i;

    generate 

        for(i=0; i<N_STREAMS; i++)begin
            assign valid_bus[i] = stream_in[i].valid;
            assign unrolled_tlast[i] = stream_in[i].tlast;
            assign unrolled_dest[i] = stream_in[i].dest;
            assign unrolled_user[i] = stream_in[i].user;
            assign unrolled_data[i] = stream_in[i].data;
            assign stream_in[i].ready = (i==address) & stream_out.ready;
        end

    endgenerate

    generate
        if(BUFFERED==1)begin
            always_ff@(posedge clock) begin
                stream_out.data <= unrolled_data[address];
                stream_out.dest <= unrolled_dest[address];
                stream_out.user <= unrolled_user[address];
                stream_out.tlast <= unrolled_tlast[address];
                stream_out.valid <= valid_bus[address];
            end
        end else begin
                assign stream_out.data = unrolled_data[address];
                assign stream_out.dest = unrolled_dest[address];
                assign stream_out.user = unrolled_user[address];
                assign stream_out.tlast = unrolled_tlast[address];
                assign stream_out.valid = valid_bus[address];
        end
    endgenerate
    
    
  

endmodule