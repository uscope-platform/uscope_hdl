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

module channel_selector #(
    int N_CHANNELS = 6,
    int DATA_WIDTH = 32,
    int DEST_WIDTH = 16,
    int USER_WIDTH = 16
)(
    input wire        clock,
    input wire        reset,
    input wire [7:0] selector,
    axi_stream.slave  data_in[N_CHANNELS],
    axi_stream.master data_out
);



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
        data_out.data <= unrolled_data[selector];
        data_out.dest <= unrolled_dest[selector];
        data_out.valid <= unrolled_valid[selector];
        data_out.user <= unrolled_user[selector];
        ready_blanking <= 1'b1<<selector;
    end



endmodule
