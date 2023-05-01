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

module fir_filter_segment #(
    parameter DATA_PATH_WIDTH = 16
)(
    input wire clock,
    input wire reset,
    input wire signed [DATA_PATH_WIDTH-1:0] data_in,
    input wire signed [DATA_PATH_WIDTH-1:0] tap,
    input wire signed [2*DATA_PATH_WIDTH-1:0] pipeline_in,
    output reg signed [2*DATA_PATH_WIDTH-1:0] pipeline_out
);


wire signed [2*DATA_PATH_WIDTH-1:0] multiplier_out;
assign multiplier_out = data_in*tap;

always_ff@(posedge clock) begin
    if(~reset) begin
        pipeline_out <= 0;
    end

    pipeline_out <= multiplier_out+pipeline_in;
end

endmodule