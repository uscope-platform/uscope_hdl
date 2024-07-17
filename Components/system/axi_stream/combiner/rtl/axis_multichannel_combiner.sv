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

module axis_multichannel_combiner #(
    parameter N_CHANNELS = 2,
    parameter DATA_WIDTH = 31,
    parameter DEST_WIDTH = 8,
    parameter USER_WIDTH = 8
)(
    input wire clock,
    input wire reset,
    axi_stream.slave data_in[N_CHANNELS],
    axi_stream.master data_out
);

    reg [DATA_WIDTH-1:0] latched_data[N_CHANNELS-1:0] = '{default:0};
    reg [DEST_WIDTH-1:0] latched_dest[N_CHANNELS-1:0] = '{default:0};
    reg [USER_WIDTH-1:0] latched_user[N_CHANNELS-1:0] = '{default:0};

    genvar i;

    generate
        for (i =0 ; i<N_CHANNELS; i++) begin
            always_ff @(posedge clock)begin
                if(data_in[i].valid)begin
                    latched_data[i] <= data_in[i].data;
                    latched_dest[i] <= data_in[i].dest;
                    latched_user[i] <= data_in[i].user;
                end
            end
        end
        
    endgenerate

    reg [$clog2(N_CHANNELS)-1:0]outputs_counter = 0;

    enum reg [2:0] { 
        init_output = 0,
        wait_data = 1,
        combining = 2
    } combiner_state = init_output;


    always_ff @(posedge clock)begin
        data_out.valid <= 0;
        case (combiner_state)
            init_output:begin
                data_out.tlast <= 0;
                data_out.data <= 0;
                data_out.dest <= 0;
                data_out.user <= 0;
                data_out.tlast <= 0;
                data_out.valid <= 0;
                combiner_state <= wait_data;
            end
            wait_data: begin
                data_out.tlast <= 0;
                if(data_in[0].valid) begin
                    combiner_state <= combining;
                    outputs_counter <= 0;
                end
            end
            combining: begin
                if(outputs_counter==N_CHANNELS-1)begin
                    combiner_state <= wait_data;
                    data_out.tlast <= 1;
                end else begin
                    outputs_counter <= outputs_counter+1;
                end
                data_out.data <= latched_data[outputs_counter];
                data_out.user <= latched_user[outputs_counter];
                data_out.dest <= latched_dest[outputs_counter];
                data_out.valid <= 1;
            end
        endcase
    end
endmodule