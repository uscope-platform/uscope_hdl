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
    parameter DATA_TYPE="INTEGER",
    parameter DATA_SRC_FILE=""
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
    
    generate
        if(DATA_SRC_FILE=="")begin
            assign selected_data = OUTPUT_BIAS + data_gen_ctr + 2000*(dest_counter - DEST_START);
            assign selected_user = get_axis_metadata(16, 1, 0);
        end else begin
        
            reg [31:0] test_data [1023:0];

            initial begin
                $readmemh(DATA_SRC_FILE, test_data);
            end
            assign selected_data = test_data[data_gen_ctr];
            assign selected_user = get_axis_metadata(32, 0, 1);

        end

    endgenerate

    enum logic [2:0]{
        fill_buffers = 0,
        idle = 1,
        wait_tb = 2,
        ctr_advance = 3, 
        wait_dma_done = 4,
        backoff = 5
    } sequencer_state = fill_buffers;


    reg [23:0] fill_ctr = 0;

    always_ff@(posedge clock)begin
        trigger_del <= trigger;
        if(!reset)begin
            data_out.data <= 0;
            data_out.valid <= 0; 
            data_out.tlast <= 0;
            sequencer_state <= fill_buffers;
        end else begin
            case(sequencer_state)
                fill_buffers:begin
                    if(fill_ctr == 128000) begin
                        sequencer_state <= idle;
                    end
                    fill_ctr <= fill_ctr + 1;
                end
                idle:begin
                    data_out.tlast <= 0;
                    data_gen_ctr <= 0;
                    if(enable || ( trigger & !trigger_del )) begin
                        sequencer_state <= wait_tb;
                    end
                end
                wait_tb:begin
                    data_out.valid <= 0;
                    if(timebase & data_out.ready)begin
                        sequencer_state <= ctr_advance;
                    end
                end
                ctr_advance:begin
 
                    if(dest_counter==(DEST_START+N_DEST-1))begin
                        dest_counter <= DEST_START;
                        data_out.tlast <= 1;
                        sequencer_state <=wait_tb;     
                        if(data_gen_ctr == 1023)begin
                            data_gen_ctr <= 0;
                        end else begin
                            data_gen_ctr <= data_gen_ctr + 1;
                        end
                        
                    end else begin
                        dest_counter <= dest_counter + 1;
                    end
                    data_out.data <= selected_data;
                    data_out.user <= selected_user;
                    data_out.dest <= dest_counter;

                    data_out.valid <= 1;
                    
                end
            endcase
        end
    end


endmodule