// Copyright 2026 Filippo Savi
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

module fp_fp32_to_fp64 (
    input wire clock,
    input wire reset,
    axi_stream.slave in,
    axi_stream.master out
);

    assign in.ready = out.ready;

    // -----------------------
    // Stage 1: Leading-One Detection
    // -----------------------

    function automatic logic [4:0] get_msb_index (input logic [22:0] value);
        integer i;
        logic [4:0] msb = 0;
        for (i = 0; i < 23; i++)
            if (value[i]) msb = 5'(i);
        get_msb_index = msb;
    endfunction

    reg        s1_valid = 0;
    reg        s1_sign;
    reg [7:0]  s1_exponent;
    reg [22:0] s1_mantissa;
    reg [4:0]  s1_msb;
    reg [31:0] s1_dest;
    reg [31:0] s1_user;
    reg        s1_tlast;

    always_ff @(posedge clock) begin
        if (~reset) begin
            s1_valid <= 0;
        end else begin
            s1_valid <= in.valid;
            s1_sign <= in.data[31];
            s1_exponent <= in.data[30:23];
            s1_mantissa <= in.data[22:0];
            s1_msb <= get_msb_index(in.data[22:0]);
            s1_dest <= in.dest;
            s1_user <= in.user;
            s1_tlast <= in.tlast;
        end
    end

    // -----------------------
    // Stage 2: Normalize, rebias exponent and pack
    // -----------------------

    // the exponent bias goes from 127 to 1023
    wire [10:0] rebased_exponent;
    assign rebased_exponent = {3'b000, s1_exponent} + 11'd896;

    // a denormal is 0.mantissa * 2^-126 = 1.fraction * 2^(msb-149), the leading one is shifted out
    wire [10:0] denormal_exponent;
    wire [22:0] denormal_fraction;
    assign denormal_exponent = 11'd874 + {6'b0, s1_msb};
    assign denormal_fraction = s1_mantissa << (5'd23 - s1_msb);

    always_ff @(posedge clock) begin
        if (~reset) begin
            out.valid <= 0;
            out.data <= 0;
            out.dest <= 0;
            out.user <= 0;
            out.tlast <= 0;
        end else begin
            out.valid <= s1_valid;
            out.dest <= s1_dest;
            out.user <= s1_user;
            out.tlast <= s1_tlast;

            if (s1_exponent == 8'h00) begin
                if (s1_mantissa == 0) begin
                    out.data <= {s1_sign, 63'b0};
                end else begin
                    out.data <= {s1_sign, denormal_exponent, denormal_fraction, 29'b0};
                end
            end else if (s1_exponent == 8'hFF) begin
                // infinity or NaN, the mantissa is kept so a NaN stays a NaN
                out.data <= {s1_sign, 11'h7FF, s1_mantissa, 29'b0};
            end else begin
                out.data <= {s1_sign, rebased_exponent, s1_mantissa, 29'b0};
            end
        end
    end

endmodule
