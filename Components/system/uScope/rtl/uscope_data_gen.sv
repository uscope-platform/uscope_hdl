// Copyright 2024 Filippo Savi
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


module uscope_data_gen #(
    parameter BACKOFF_DELAY = 128,
    parameter OUTPUT_BIAS = 0,
    parameter DEST_START = 1,
    parameter N_DEST = 6,
    parameter DATA_TYPE="INTEGER"
)(
    input wire        clock,
    input wire        reset,
    input wire        enable,
    input wire        timebase,
    input wire        trigger,
    input wire        dma_done,
    input wire [31:0] packet_length,
    axi_stream.master  data_out
);


    reg [7:0] dest_counter = DEST_START;
    reg [15:0] data_gen_ctr;
    reg [15:0] delay_counter = 0;

    reg trigger_del;

    wire [31:0] selected_data;
    wire [15:0] selected_user;
    
    assign selected_data = OUTPUT_BIAS + data_gen_ctr + 2000*(dest_counter - DEST_START);
    assign selected_user = get_axis_metadata(16, 1, 0);

    enum logic [2:0]{
        idle = 0,
        wait_tb = 1,
        ctr_advance = 2, 
        wait_dma_done = 3,
        backoff = 4
    } sequencer_state = idle;


    always_ff@(posedge clock)begin
        trigger_del <= trigger;
        if(!reset)begin
            data_out.data <= 0;
            data_out.valid <= 0; 
            data_out.tlast <= 0;
            sequencer_state <= idle;
        end else begin
            case(sequencer_state)
                idle:begin
                    data_out.tlast <= 0;
                    data_gen_ctr <= 0;
                    if(enable || ( trigger & !trigger_del )) begin
                        sequencer_state <= wait_tb;
                    end
                end
                wait_tb:begin
                    data_out.valid <= 0;
                    if(timebase)begin
                        sequencer_state <= ctr_advance;
                    end
                end
                ctr_advance:begin

                    if(dest_counter==(DEST_START+N_DEST-1))begin
                        dest_counter <= DEST_START;
                        data_out.tlast <= 1;
                        sequencer_state <=wait_tb;     
                        data_gen_ctr <= data_gen_ctr + 1;
                    end else begin
                        dest_counter <= dest_counter + 1;
                    end

                    if(~data_out.ready)begin
                        sequencer_state <=wait_dma_done;  
                    end


                    data_out.data <= selected_data;
                    data_out.user <= selected_user;
                    data_out.dest <= dest_counter;

                    data_out.valid <= 1;
                    
                end
                wait_dma_done:begin
                    data_out.valid <= 0;
                    delay_counter <= 0;
                    data_gen_ctr <= 0;
                    data_out.tlast <= 0;
                    if(dma_done)begin
                        sequencer_state <= backoff;
                    end
                end
                backoff:begin
                    if(delay_counter == BACKOFF_DELAY-1)begin
                        sequencer_state <= idle;
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end
            endcase
        end
    end


endmodule