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

module fir_filter_slice #(
    parameter DATA_PATH_WIDTH = 16,
    TAP_WIDTH = 16,
    WORKING_WIDTH = DATA_PATH_WIDTH > TAP_WIDTH ? DATA_PATH_WIDTH : TAP_WIDTH
)(
    input wire clock,
    input wire signed [WORKING_WIDTH-1:0] data_in,
    input wire in_valid,
    input wire signed [WORKING_WIDTH-1:0] tap,
    input wire signed [2*WORKING_WIDTH-1:0] pipeline_in,
    output wire signed [2*WORKING_WIDTH-1:0] pipeline_out,
    output reg out_valid
);

    reg signed [2*WORKING_WIDTH-1:0] internal_out = 0;
    wire signed [2*WORKING_WIDTH-1:0] multiplier_out;

    assign pipeline_out = internal_out;
    assign multiplier_out = data_in*tap;

    always_ff@(posedge clock) begin
        if(in_valid)begin
            internal_out <= multiplier_out+pipeline_in;
        end
        out_valid <= in_valid;
    end

endmodule