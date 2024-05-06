// Copyright 2023 Filippo Savi
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

module linearizer #(
    parameter DATA_PATH_WIDTH = 16,
    parameter DEST_WIDTH = 8,
    parameter USER_WIDTH = 16,
    DATA_BLOCK_BASE_ADDR = 0,
    N_CHANNELS = 1,
    N_SEGMENTS = 4,
    parameter [DATA_PATH_WIDTH-1:0] BOUNDS [N_CHANNELS-1:0][N_SEGMENTS-1:0] = '{default:0},
    parameter [DATA_PATH_WIDTH:0] GAINS [N_CHANNELS-1:0][N_SEGMENTS-1:0] = '{default:0}
    )(
    input wire clock,
    input wire reset,
    input wire enable,
    axi_stream.slave data_in,
    axi_stream.master data_out
);

    reg [DATA_PATH_WIDTH-1:0] channel_data [N_CHANNELS-1:0]  = '{default:0};
    reg [2*DATA_PATH_WIDTH-1:0] linear_channel_data [N_CHANNELS-1:0] = '{default:0};
    

    reg signed [2*DATA_PATH_WIDTH-1:0] linearized_data = 0;
    reg signed [DATA_PATH_WIDTH-1:0] linearized_dest = 0;
    reg linearized_valid = 0;

    always_comb begin
        if(enable)begin
            data_out.data <= linear_channel_data[in_dest_del];
            data_out.dest <= in_dest_del;
            data_out.user <= in_user_del;
            data_out.valid <= in_valid_del;
        end else begin
            data_out.data <= data_in.data;
            data_out.dest <= data_in.dest;
            data_out.user <= data_in.user;
            data_out.valid <= data_in.valid;
        end
        data_in.ready <= data_out.ready;
    end
   
    reg in_valid_del;
    reg [DEST_WIDTH-1:0] in_dest_del;
    reg [USER_WIDTH-1:0] in_user_del;

    always @(posedge clock)begin
        in_valid_del <= data_in.valid;
        in_dest_del <= data_in.dest;
        in_user_del <= data_in.user;
        if(data_in.valid) begin
            channel_data[data_in.dest - DATA_BLOCK_BASE_ADDR] <= data_in.data;
        end
    end

    genvar i, j;
    generate 

        for(i = 0; i<N_CHANNELS; i++)begin
            // USE A BANK OF WINDOW COMPARATORS TO FIND THE CORRECT GAIN TO APPLY
            reg [N_SEGMENTS-1:0] window_flags;
            for(j = 0; j<N_SEGMENTS-1; j++)begin
                always_comb begin
                    if(data_in.valid && data_in.dest == i) begin
                        window_flags[j] <= data_in.data>=BOUNDS[i][j] && data_in.data<BOUNDS[i][j+1];
                    end else begin
                        window_flags[j] <= 0;
                    end   
                end
            end

            always_comb begin
                window_flags[N_SEGMENTS-1] <= data_in.data>=BOUNDS[i][N_SEGMENTS-1];
            end
            reg [31:0] selected_gain;
            // APPLY THE GAIN AS A FIXED POINT INTEGER MULTIPLICATION
            always_ff@(posedge clock)begin
                if(data_in.valid && data_in.dest == i)begin
                    for(integer k = 0; k<N_SEGMENTS; k++) begin
                        if(window_flags[k])begin
                            selected_gain <= GAINS[i][k];
                            linear_channel_data[i] <= (data_in.data*GAINS[i][k]) >>>DATA_PATH_WIDTH;
                        end
                    end
                end
            end
        end
    endgenerate

endmodule