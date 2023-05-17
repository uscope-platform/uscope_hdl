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
    N_CHANNELS = 1,
    N_SEGMENTS = 4,
    parameter [DATA_PATH_WIDTH-1:0] BOUNDS [N_SEGMENTS-1:0] = '{0},
    parameter [DATA_PATH_WIDTH:0] GAINS [N_CHANNELS-1:0][N_SEGMENTS-1:0] = '{'{0}}
    )(
    input wire clock,
    input wire reset,
    input wire enable,
    axi_stream.slave data_in,
    axi_stream.master data_out
);

    reg [DATA_PATH_WIDTH-1:0] channel_data [N_CHANNELS-1:0];
    reg [2*DATA_PATH_WIDTH-1:0] linear_channel_data [N_CHANNELS-1:0];
    

    reg signed [2*DATA_PATH_WIDTH-1:0] linearized_data = 0;
    reg signed [DATA_PATH_WIDTH-1:0] linearized_dest = 0;
    reg linearized_valid = 0;

    always_comb begin
        if(enable)begin
            data_out.data <= linear_channel_data[in_dest_del];
            data_out.dest <= in_dest_del;
            data_out.valid <= in_valid_del;
        end else begin
            data_out.data <= data_in.data;
            data_out.dest <= data_in.dest;
            data_out.valid <= data_in.valid;
        end
        data_in.ready <= data_out.ready;
    end
   
    reg in_valid_del;
    reg [7:0] in_dest_del;

    always @(posedge clock)begin
        in_valid_del <= data_in.valid;
        in_dest_del <= data_in.dest;
        if(data_in.valid) begin
            channel_data[data_in.dest] <= data_in.data;
        end
    end

    genvar i;
    generate 
        for(i = 0; i<N_CHANNELS; i++)begin
            always_ff@(posedge clock)begin
                if(data_in.valid && data_in.dest == i)begin
                    if(data_in.data>=BOUNDS[0] && data_in.data<BOUNDS[1])begin
                        linear_channel_data[i] <= (data_in.data*GAINS[i][0])>>>DATA_PATH_WIDTH;
                    end else if(data_in.data>=BOUNDS[1] && data_in.data<BOUNDS[2])begin
                        linear_channel_data[i] <= (data_in.data*GAINS[i][1])>>>DATA_PATH_WIDTH;
                    end else begin
                        linear_channel_data[i] <= (data_in.data*GAINS[i][2])>>>DATA_PATH_WIDTH;
                    end
                end
                
            end
        end
    endgenerate

endmodule