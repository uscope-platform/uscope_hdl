// Copyright 2021 Filippo Savi
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

module CORDIC_atan#(
    parameter integer RESOLUTION = 16,
    parameter bit OUTPUT_0_2PI = 1'b0 // 0: angle in [-PI, PI), 1: angle in [0, 2*PI)
)(
    input wire clock,
    input wire reset,
    axi_stream.slave x, 
    axi_stream.slave y,
    axi_stream.master out
);


    axi_stream initial_condition();


    CORDIC_quadrant_selector#(
        .RESOLUTION(RESOLUTION)
    )pre_rotator(
        .clock(clock),
        .reset(reset),
        .x_in(x),
        .y_in(y),
        .prescaled_out(initial_condition)
    );

    CORDIC_core#(
        .RESOLUTION(RESOLUTION),
        .OUTPUT_0_2PI(OUTPUT_0_2PI)
    )serial_core(
        .clock(clock),
        .reset(reset),
        .initial_condition(initial_condition),
        .out(out)
    );



endmodule