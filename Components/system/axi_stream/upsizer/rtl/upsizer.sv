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

`timescale 10ns / 1ns
`include "interfaces.svh"

module upsizer#(
    parameter INPUT_WIDTH = 64,
    parameter OUTPUT_WIDTH = 128,
    parameter DEST_WIDTH = 16,
    parameter USER_WIDTH = 16
)(
    input wire clock,
    input wire reset,
    axi_stream.slave data_in,
    axi_stream.master data_out
);


    generate
        if(INPUT_WIDTH == OUTPUT_WIDTH)begin

            assign data_in.ready = data_out.ready;
            assign data_out.dest = data_in.dest;
            assign data_out.tlast = data_in.tlast;
            assign data_out.user = data_in.user;
            assign data_out.data = data_in.data;

        end else begin

            axi_stream #(.DATA_WIDTH(INPUT_WIDTH), .DEST_WIDTH(DEST_WIDTH), .USER_WIDTH(USER_WIDTH)) data_in_buffered();


            axis_skid_buffer #(
                .REGISTER_OUTPUT(0),
                .LATCHING(0),
                .DATA_WIDTH(INPUT_WIDTH),
                .DEST_WIDTH(DEST_WIDTH),
                .USER_WIDTH(USER_WIDTH)
            ) backpressure_buffer (
                .clock(clock),
                .reset(reset),
                .axis_in(data_in),
                .axis_out(data_in_buffered)
            );

            localparam UPSIZING_RATIO = OUTPUT_WIDTH/INPUT_WIDTH;

            reg [INPUT_WIDTH-1:0] input_data_buffer [UPSIZING_RATIO-2:0];
            reg [DEST_WIDTH-1:0] input_dest_buffer [UPSIZING_RATIO-2:0];
            reg [USER_WIDTH-1:0] input_user_buffer [UPSIZING_RATIO-2:0];

            reg [$clog2(UPSIZING_RATIO)-1:0] fill_counter = 0;

            assign data_in_buffered.ready = data_out.ready;

            enum reg { 
                fill_buffer = 0,
                push_output = 1
            } upsizer_fsm = fill_buffer;

            always_ff @(posedge clock)begin
                case (upsizer_fsm)
                    fill_buffer:begin
                        data_out.valid <= 0 ;
                        if(data_in_buffered.valid & data_out.ready)begin
                            if(fill_counter == UPSIZING_RATIO-2)begin
                                upsizer_fsm <= push_output;
                            end else begin
                                fill_counter <= fill_counter + 1;
                            end
                            input_data_buffer[fill_counter] <= data_in_buffered.data;
                            input_dest_buffer[fill_counter] <= data_in_buffered.dest;
                            input_user_buffer[fill_counter] <= data_in_buffered.user;
                        end
                    end 
                    push_output:begin
                        if(data_in_buffered.valid & data_out.ready)begin
                            upsizer_fsm <= fill_buffer;
                            data_out.valid <= 1;
                            data_out.data <= {data_in_buffered.data, input_data_buffer[0]};
                            data_out.dest <= input_dest_buffer[0];
                            data_out.user <= input_user_buffer[0];
                        end
                    end 
                endcase
            end
        end
    endgenerate

endmodule
