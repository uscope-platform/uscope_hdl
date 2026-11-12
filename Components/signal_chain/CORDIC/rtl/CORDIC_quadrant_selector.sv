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

module CORDIC_quadrant_selector#(
    parameter integer RESOLUTION = 16
)(
    input wire clock,
    input wire reset,
    axi_stream.slave x_in,
    axi_stream.slave y_in,
    axi_stream.master prescaled_out
);

    // Q1.15 scaling: PI = 180 deg = 32768 = 2**(RESOLUTION-1)
    localparam signed [RESOLUTION-1:0] ANG_PI_2 = 2**(RESOLUTION-2);

    axi_stream #(
        .DATA_WIDTH(x_in.DATA_WIDTH),
        .USER_WIDTH(x_in.USER_WIDTH),
        .DEST_WIDTH(x_in.DEST_WIDTH)
    ) x_buf();

    axis_skid_buffer #(
        .REGISTER_OUTPUT(0),
        .LATCHING(0)
    ) in_skid_x (
        .clock(clock),
        .reset(reset),
        .axis_in(x_in),
        .axis_out(x_buf)
    );

    assign x_buf.ready = prescaled_out.ready;

    axi_stream #(
        .DATA_WIDTH(y_in.DATA_WIDTH),
        .USER_WIDTH(y_in.USER_WIDTH),
        .DEST_WIDTH(y_in.DEST_WIDTH)
    ) y_buf();

    axis_skid_buffer #(
        .REGISTER_OUTPUT(0),
        .LATCHING(0)
    ) in_skid_y (
        .clock(clock),
        .reset(reset),
        .axis_in(y_in),
        .axis_out(y_buf)
    );

    assign y_buf.ready = prescaled_out.ready;
    
    reg new_sample = 0;

    reg signed [15:0] scaled_x = 0;
    reg signed [15:0] scaled_y = 0;
    reg signed [15:0] z_start = 0;

    assign prescaled_out.data[15:0] = scaled_x;
    assign prescaled_out.data[31:16] = scaled_y;
    assign prescaled_out.user = z_start;

    wire signed [15:0] x_in_b = x_buf.data[15:0];
    wire signed [15:0] y_in_b = y_buf.data[15:0];
    
    always_ff @(posedge clock) begin
        prescaled_out.valid <= 0;

        if (y_buf.valid && y_buf.ready && x_buf.valid && x_buf.ready) begin


            // 180-degree pre-rotation for Quadrants II & III (x < 0)
            if (x_in_b < 0) begin
                if (y_in_b >= 0) begin
                    scaled_x <= y_in_b;
                    scaled_y <= -x_in_b;
                    z_start <= ANG_PI_2;
                end else begin
                    scaled_x <= -y_in_b;
                    scaled_y <= x_in_b;
                    z_start <= -ANG_PI_2;
                end
            end else begin
                // Q1 & Q4: Pass through
                scaled_x <= x_in_b;
                scaled_y <= y_in_b;
                z_start <= 16'sd0;
            end

            if (prescaled_out.ready) begin
                prescaled_out.valid <= 1;
            end else begin
                new_sample <= 1;
            end
        end

        if (new_sample && prescaled_out.ready) begin
            new_sample <= 0;
            prescaled_out.valid <= 1;
        end
    end

endmodule