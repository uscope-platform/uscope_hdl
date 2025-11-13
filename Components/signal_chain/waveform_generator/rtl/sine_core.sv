// Copyright 2025 Filippo Savi
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

`timescale 10ns / 1ns
module sine_core #(
    integer N_PARAMETERS = 16,
    integer TIMEBASE_WIDTH = 24
)(
    input wire clock,
    input wire reset,
    input wire trigger,
    input wire [31:0] parameters[N_PARAMETERS-1:0],
    axi_stream.master data_out
);


    wire [31:0] dc_offset;
    assign dc_offset = parameters[0];

    wire [31:0] amplitude;
    assign amplitude = parameters[1];

    wire [31:0] frequency;
    assign frequency = parameters[2];

    wire [31:0] phase;
    assign phase = parameters[3];

    initial begin
        data_out.data = 0;
        data_out.dest = 0;
        data_out.tlast = 0;
        data_out.valid = 0;
        data_out.user = 0;
    end

    reg enabled = 0;

    reg [15:0] angle = 0;
    wire [15:0] raw_cos, raw_cos_next, refined_out;
    reg [15:0] cos_out;

    always_ff@(posedge clock) begin
        if(trigger) enabled <= 1;
        if(enabled)begin
            angle <= angle + 1;
            data_out.valid <= 1;
        end
        data_out.data <= {{16{raw_cos[15]}}, raw_cos};
        //data_out.data <= {{16{refined_out[15]}}, refined_out};
    end

    sine_lut #(
        .LUT_DEPTH(256),
        .INPUT_DATA_WIDTH(14),
        .OUTPUT_WIDTH(16)
    )lut_9(
        .angle(angle[15:2]),
        .cos(raw_cos),
        .cos_next(raw_cos_next)
    );

    interpolating_enhancer #(
        .DATA_WIDTH(16)
    )interpolation(
        .clock(clock),
        .cos(raw_cos),
        .cos_next(raw_cos_next),
        .selector(angle[1:0]),
        .cos_out(refined_out)
    );

    
endmodule
