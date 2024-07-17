

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

`timescale 10 ns / 1 ns
`include "interfaces.svh"


module stream_delayer #(
    parameter DATA_WIDTH= 32, 
    DEST_WIDTH = 32,
    USER_WIDTH = 32,
    BUFFER_DEPTH = 16,
    TARGET_DEST = 0
)(
    input wire        clock,
    input wire        reset,
    input wire start,
    axi_stream.slave  in,
    axi_stream.master out
);

    reg[DATA_WIDTH-1:0] data_memory [BUFFER_DEPTH-1:0] = '{default:0};
    reg[DATA_WIDTH-1:0] dest_memory [BUFFER_DEPTH-1:0] = '{default:0};
    reg[DATA_WIDTH-1:0] user_memory [BUFFER_DEPTH-1:0] = '{default:0};

    initial begin
        out.data <= 0;
        out.dest <= 0;
        out.user <= 0;
        out.tlast <= 0;
        out.valid <= 0;
    end

    reg [15:0] fill_ctr = 0;
    reg [15:0] read_ctr = 0;
    
    reg read_in_progress = 0;
    
    always_ff@(posedge clock)begin
        in.ready <= 1;
        if(in.valid)begin
            data_memory[fill_ctr] <=  in.data;
            dest_memory[fill_ctr] <=  in.dest;
            user_memory[fill_ctr] <=  in.user;
            fill_ctr <= fill_ctr +1;
        end 

        if(out.tlast)begin
            fill_ctr <= 0;
        end

        if(start)begin
           read_in_progress <= 1;
        end

        if(read_in_progress)begin
            if(read_ctr==fill_ctr-1)begin
                read_ctr <= 0;
                read_in_progress<= 0;
            end else begin
                read_ctr <= read_ctr+1;
            end
        end
        
    end

    always_ff@(posedge clock)begin
        out.tlast <=0;
        out.valid <= 0;
        if(read_in_progress) begin
            out.valid <= 1;
            out.data <= data_memory[read_ctr];
            out.user <= user_memory[read_ctr];
            out.dest <= dest_memory[read_ctr];
            if(read_ctr == fill_ctr-1)begin
                out.tlast <=1;
            end
        end
        
    end

endmodule
