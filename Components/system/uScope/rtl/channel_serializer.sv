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


module channel_serializer #(
    N_CHANNELS = 6,
    SAMPLES_PER_CHANNEL = 1024,
    DATA_WIDTH = 32,
    DEST_WIDTH = 16,
    USER_WIDTH = 16
)(
    input wire        clock,
    input wire        reset,
    input wire        trigger,
    axi_stream.slave  data_in[N_CHANNELS],
    axi_stream.master data_out
);

    enum reg [2:0] { 
        wait_trigger = 0,
        data_transfer = 1
    } state = wait_trigger;


    reg [N_CHANNELS-1:0] ready_blanking = 1;
    wire [N_CHANNELS-1:0] unrolled_valid;
    wire [N_CHANNELS-1:0] unrolled_tlast;
    wire [DATA_WIDTH-1:0] unrolled_data [N_CHANNELS-1:0];
    wire [DEST_WIDTH-1:0] unrolled_dest [N_CHANNELS-1:0];
    wire [USER_WIDTH-1:0] unrolled_user [N_CHANNELS-1:0];

    generate
    genvar i;
    for(i = 0; i<N_CHANNELS; i++)begin
        assign unrolled_data[i] = data_in[i].data;
        assign unrolled_dest[i] = data_in[i].dest;
        assign unrolled_user[i] = data_in[i].user;
        assign unrolled_valid[i] = data_in[i].valid;
        assign unrolled_tlast[i] = data_in[i].tlast;
        assign data_in[i].ready = ready_blanking[i] & data_out.ready;
    end
    endgenerate
    

    reg [$clog2(N_CHANNELS)-1:0] channels_counter = 0;

    always_comb begin
        data_out.data <= unrolled_data[channels_counter];
        data_out.dest <= unrolled_dest[channels_counter];
        data_out.valid <= unrolled_valid[channels_counter];
        data_out.user <= unrolled_user[channels_counter];
        ready_blanking <= 1'b1<<channels_counter;
    end

    always @(posedge clock) begin
        case (state)
            wait_trigger:begin
                if(trigger)begin
                    state <= data_transfer;
                end
            end
            data_transfer: begin
                if(unrolled_tlast[channels_counter] & unrolled_valid[channels_counter])begin
                    if(channels_counter == N_CHANNELS-1)begin
                        channels_counter <= 0;
                        state <= wait_trigger;
                    end else begin
                        channels_counter <= channels_counter + 1;
                    end
                end
            end
        endcase
        
    end



    

endmodule
