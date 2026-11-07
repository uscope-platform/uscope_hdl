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

// Double to single precision conversion, rounds to nearest even.
// Results too small for a normal number after rounding are flushed to zero, results too big become infinity.
// Latency is two clock cycles.
module fp_fp64_to_fp32 (
    input wire clock,
    input wire reset,
    axi_stream.slave in,
    axi_stream.master out
);

    localparam CLASS_ZERO = 0;
    localparam CLASS_NORMAL = 1;
    localparam CLASS_INFINITY = 2;
    localparam CLASS_NAN = 3;
    localparam CLASS_SMALLEST_NORMAL = 4;

    assign in.ready = out.ready;

    // -----------------------
    // Stage 1: Classify, rebias exponent, compute rounding
    // -----------------------

    wire        sign;
    wire [10:0] exponent;
    wire [51:0] mantissa;
    assign sign = in.data[63];
    assign exponent = in.data[62:52];
    assign mantissa = in.data[51:0];

    // the exponent bias goes from 1023 to 127
    wire signed [12:0] rebased_exponent;
    assign rebased_exponent = $signed({2'b00, exponent}) - 13'sd896;

    // round to nearest even: guard is the first discarded bit, sticky is the OR of the others
    wire guard;
    wire sticky;
    assign guard = mantissa[28];
    assign sticky = |mantissa[27:0];

    reg        s1_valid = 0;
    reg        s1_sign;
    reg [2:0]  s1_class;
    reg signed [12:0] s1_exponent;
    reg [22:0] s1_mantissa;
    reg        s1_round_up;
    reg [31:0] s1_dest;
    reg [31:0] s1_user;
    reg        s1_tlast;

    always_ff @(posedge clock) begin
        if (~reset) begin
            s1_valid <= 0;
        end else begin
            s1_valid <= in.valid;
            s1_sign <= sign;
            s1_exponent <= rebased_exponent;
            s1_mantissa <= mantissa[51:29];
            s1_round_up <= guard & (sticky | mantissa[29]);
            s1_dest <= in.dest;
            s1_user <= in.user;
            s1_tlast <= in.tlast;

            if (exponent == 11'h7FF) begin
                s1_class <= (mantissa == 0) ? CLASS_INFINITY : CLASS_NAN;
            end else if (rebased_exponent == 0 && mantissa[51:28] == 24'hFFFFFF) begin
                // just below the smallest normal number, close enough to round up to it
                s1_class <= CLASS_SMALLEST_NORMAL;
            end else if (rebased_exponent <= 0) begin
                // zero, denormal, or too small for a normal single precision number
                s1_class <= CLASS_ZERO;
            end else if (rebased_exponent >= 255) begin
                s1_class <= CLASS_INFINITY;
            end else begin
                s1_class <= CLASS_NORMAL;
            end
        end
    end

    // -----------------------
    // Stage 2: Round and pack
    // -----------------------

    wire [23:0] rounded_mantissa;
    assign rounded_mantissa = {1'b0, s1_mantissa} + {23'b0, s1_round_up};

    // a mantissa that rounds up to 2.0 bumps the exponent
    wire carry;
    wire signed [12:0] rounded_exponent;
    assign carry = rounded_mantissa[23];
    assign rounded_exponent = s1_exponent + $signed({12'b0, carry});

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

            case (s1_class)
                CLASS_ZERO: begin
                    out.data <= {s1_sign, 31'b0};
                end
                CLASS_INFINITY: begin
                    out.data <= {s1_sign, 8'hFF, 23'b0};
                end
                CLASS_SMALLEST_NORMAL: begin
                    out.data <= {s1_sign, 8'h01, 23'b0};
                end
                CLASS_NAN: begin
                    // always a quiet NaN
                    out.data <= {s1_sign, 8'hFF, 1'b1, s1_mantissa[21:0]};
                end
                default: begin
                    if (rounded_exponent >= 255) begin
                        out.data <= {s1_sign, 8'hFF, 23'b0};
                    end else if (carry) begin
                        out.data <= {s1_sign, rounded_exponent[7:0], 23'b0};
                    end else begin
                        out.data <= {s1_sign, rounded_exponent[7:0], rounded_mantissa[22:0]};
                    end
                end
            endcase
        end
    end

endmodule
