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

module sigma_delta_integration_stage #(
    parameter DATA_PATH_WIDTH = 16
)(
    input wire clock,
    input wire reset,
    input wire modulation_clock,
    input wire data_in,
    output wire [DATA_PATH_WIDTH-1:0] data_out
);

    reg [DATA_PATH_WIDTH-1:0] accumulation [2:0] = '{0,0,0};
    assign data_out = accumulation[2];

    sd_integrator #(
        .DATA_PATH_WIDTH(DATA_PATH_WIDTH)
    ) int_0 (
        .clock(clock),
        .reset(reset),
        .data_clock(modulation_clock),
        .data_in({{DATA_PATH_WIDTH-1{1'b0}},data_in}),
        .data_out(accumulation[0])
    );

    sd_integrator #(
        .DATA_PATH_WIDTH(DATA_PATH_WIDTH)
    ) int_1 (
        .clock(clock),
        .reset(reset),
        .data_clock(modulation_clock),
        .data_in(accumulation[0]),
        .data_out(accumulation[1])
    );

    sd_integrator #(
        .DATA_PATH_WIDTH(DATA_PATH_WIDTH)
    ) int_2 (
        .clock(clock),
        .reset(reset),
        .data_clock(modulation_clock),
        .data_in(accumulation[1]),
        .data_out(accumulation[2])
    );


endmodule