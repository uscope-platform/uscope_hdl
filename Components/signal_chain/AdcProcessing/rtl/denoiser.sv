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

module denoiser #(
    parameter DATA_PATH_WIDTH = 16,
    N_CHANNELS = 1
)(
    input wire clock,
    input wire reset,
    input wire signed [DATA_PATH_WIDTH-1 :0] thresh_p [N_CHANNELS-1 :0],
    input wire signed [DATA_PATH_WIDTH-1 :0] thresh_n [N_CHANNELS-1 :0],
    input wire enable,
    axi_stream.slave data_in,
    axi_stream.master data_out
);

    reg signed  [DATA_PATH_WIDTH-1 :0] last_good_data [ N_CHANNELS-1 :0] = '{N_CHANNELS{32'd0}};
    wire signed [DATA_PATH_WIDTH-1 :0] current_data_in;
    
    wire signed [DATA_PATH_WIDTH-1 :0] positive_diff;
    wire signed [DATA_PATH_WIDTH-1 :0] negative_diff;

    assign positive_diff = current_data_in-last_good_data[data_in.dest];
    assign negative_diff = current_data_in-last_good_data[data_in.dest];

    assign data_in.ready = data_out.ready | ~reset ? 1 : 0;

    assign current_data_in = $signed(data_in.data);

    always @(posedge clock)begin
        if(~reset) begin
            data_out.data <= 0;
            data_out.dest <= 0;
            data_out.valid <=0;
        end else begin
            if(data_in.valid)begin
                if(enable &&
                    (
                    positive_diff > thresh_p[data_in.dest] ||
                    negative_diff < thresh_n[data_in.dest]
                    )
                ) begin
                    data_out.data <= last_good_data[data_in.dest];
                end else begin
                    data_out.data <= data_in.data;
                    last_good_data[data_in.dest] <= current_data_in;
                end
                data_out.user <= data_in.user;
                data_out.dest <= data_in.dest;
                data_out.valid <= data_in.valid;
            end else begin

                data_out.valid <= 0;
            end
           
        end
    end


endmodule