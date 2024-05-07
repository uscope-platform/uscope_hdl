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

module sigma_delta_differentiation_stage #(
    parameter PROCESSING_RESOLUTION = 16
)(
    input wire clock,
    input wire samplink_clock,
    input wire reset,
    input wire [PROCESSING_RESOLUTION-1:0] data_in,
    output wire [PROCESSING_RESOLUTION-1:0] data_out
);


    reg [PROCESSING_RESOLUTION-1:0] differentiators [2:0];
    assign data_out = differentiators[2];

    sd_differentiator #(
        .PROCESSING_RESOLUTION(PROCESSING_RESOLUTION)
    ) diff_0 (
        .clock(clock),
        .reset(reset),
        .data_clock(samplink_clock),
        .data_in(data_in),
        .data_out(differentiators[0])
    );

    sd_differentiator #(
        .PROCESSING_RESOLUTION(PROCESSING_RESOLUTION)
    ) diff_1 (
        .clock(clock),
        .reset(reset),
        .data_clock(samplink_clock),
        .data_in(differentiators[0]),
        .data_out(differentiators[1])
    );

    sd_differentiator #(
        .PROCESSING_RESOLUTION(PROCESSING_RESOLUTION)
    ) diff_2 (
        .clock(clock),
        .reset(reset),
        .data_clock(samplink_clock),
        .data_in(differentiators[1]),
        .data_out(differentiators[2])
    );

endmodule