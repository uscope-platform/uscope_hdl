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

module axi_stream_watching_combiner #(
    parameter INPUT_DATA_WIDTH = 16, 
    OUTPUT_DATA_WIDTH = 32, 
    DEST_WIDTH = 8, 
    USER_WIDTH = 8,
    N_STREAMS = 6,
    BUFFER_DEPTH = 16
)(
    input wire clock,
    input wire reset,
    axi_stream.watcher stream_in[N_STREAMS],
    axi_stream.master stream_out
);

    axi_stream #(
        .DATA_WIDTH(INPUT_DATA_WIDTH),
        .DEST_WIDTH(DEST_WIDTH),
        .USER_WIDTH(USER_WIDTH)
    ) stream_in_buf[N_STREAMS]();

    
    genvar i;
    generate
        if(BUFFER_DEPTH>=16)begin
            for(i = 0; i<N_STREAMS; i++)begin
            
                axis_watching_fifo_xpm #(
                    .DATA_WIDTH(INPUT_DATA_WIDTH),
                    .DEST_WIDTH(DEST_WIDTH),
                    .USER_WIDTH(USER_WIDTH),
                    .FIFO_DEPTH(BUFFER_DEPTH)
                )input_buffers(
                    .clock(clock),
                    .reset(reset),
                    .in(stream_in[i]),
                    .out(stream_in_buf[i])
                );

            end  
        end else begin
            for(i = 0; i<N_STREAMS; i++)begin
            
                axis_watching_fifo #(
                    .DATA_WIDTH(INPUT_DATA_WIDTH),
                    .DEST_WIDTH(DEST_WIDTH),
                    .USER_WIDTH(USER_WIDTH),
                    .FIFO_DEPTH(BUFFER_DEPTH)
                ) input_buffers (
                    .clock(clock),
                    .reset(reset),
                    .in(stream_in[i]),
                    .out(stream_in_buf[i])
                );
            end
        end
        

    endgenerate

    wire [N_STREAMS-1:0]valid_bus;
    wire [N_STREAMS-1:0] unrolled_tlast;
    wire [DEST_WIDTH-1:0] unrolled_dest [N_STREAMS-1:0];
    wire [USER_WIDTH-1:0] unrolled_user [N_STREAMS-1:0];
    wire [INPUT_DATA_WIDTH-1:0] unrolled_data [N_STREAMS-1:0];

    wire [N_STREAMS-1:0] ready_gating;
    generate 

        for(i=0; i<N_STREAMS; i++)begin
            assign valid_bus[i] = stream_in_buf[i].valid;
            assign unrolled_tlast[i] = stream_in_buf[i].tlast;
            assign unrolled_dest[i] = stream_in_buf[i].dest;
            assign unrolled_user[i] = stream_in_buf[i].user;
            assign unrolled_data[i] = stream_in_buf[i].data;

            if(i>0)begin
                assign stream_in_buf[i].ready = stream_out.ready & ~ready_gating[i];
            end else begin
                assign stream_in_buf[i].ready = stream_out.ready & ~ready_gating[i];
            end
        end

        assign ready_gating[0] = 0;

        for(i=1; i<N_STREAMS; i++)begin
            assign ready_gating[i] = |valid_bus[i-1:0];
        end

    endgenerate


    ///////////////STREAM COMBINATION SECTION///////////////


    always@(posedge clock)begin

        for(int k = N_STREAMS-1; k>=0; k--)begin
            if(valid_bus[k])begin
                stream_out.tlast <= unrolled_tlast[k];
                stream_out.user <= unrolled_user[k];
                stream_out.dest <= unrolled_dest[k];
                stream_out.data <= {{(OUTPUT_DATA_WIDTH-INPUT_DATA_WIDTH){1'b0}},unrolled_data[k]};
                stream_out.valid <=1;
            end

            if(valid_bus == 0)begin
                stream_out.valid <= 0;
            end
        end

    end

endmodule