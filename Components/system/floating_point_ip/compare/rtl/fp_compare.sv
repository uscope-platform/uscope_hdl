
// Copyright 2024 Filippo Savi
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

module fp_compare #(
    parameter string IEEE_COMPLIANT = "TRUE"
)(
    input wire clock,
    axi_stream.slave in_a,
    axi_stream.slave in_b,
    axi_stream.master out
);

    // OUTPUT ENCODING
    // 0: A == B
    // 1: A > B
    // 2: A < B
    // 3: A != B (For special values like NaNs)

    wire signed [7:0] exponent_a;
    wire [22:0] mantissa_a;
    wire sign_a;
    wire signed [7:0] exponent_b;
    wire [22:0] mantissa_b;
    wire sign_b;


    assign sign_a = in_a.data[31];
    assign exponent_a = in_a.data[30:23]-127;
    assign mantissa_a = in_a.data[22:0];

    assign sign_b = in_b.data[31];
    assign exponent_b = in_b.data[30:23]-127;
    assign mantissa_b = in_b.data[22:0];


    //////////////////////////////////////////////////////
    //            stage 1: components comparison        //
    //////////////////////////////////////////////////////
    reg reg_valid;
    reg s1_valid, s1_sign_a;

    reg [1:0] exp_comp;
    reg [1:0] mant_comp;
    reg [1:0] sign_comp;

    always_ff@(posedge clock)begin
        reg_valid <= in_a.valid && in_b.valid;
        s1_sign_a <= sign_a;
        s1_valid <= reg_valid;
        if(in_a.valid && in_b.valid) begin
            // These only apply if the signs match, so I can check only a to see if i am comparing positive or negative numbers
            if(sign_a)begin 
                if(exponent_a > exponent_b) exp_comp <= 2'b10;
                else if(exponent_a < exponent_b) exp_comp <= 2'b01;
                else exp_comp <= 2'b00;

                if(mantissa_a > mantissa_b) mant_comp <= 2'b10;
                else if(mantissa_a < mantissa_b) mant_comp <= 2'b01;
                else mant_comp <= 2'b00;
            end else begin
                if(exponent_a > exponent_b) exp_comp <= 2'b01;
                else if(exponent_a < exponent_b) exp_comp <= 2'b10;
                else exp_comp <= 2'b00;

                if(mantissa_a > mantissa_b) mant_comp <= 2'b01;
                else if(mantissa_a < mantissa_b) mant_comp <= 2'b10;
                else mant_comp <= 2'b00;
            end


            if(~sign_a && sign_b) sign_comp <= 2'b01;
            else if(sign_a && ~sign_b) sign_comp <= 2'b10;
            else sign_comp <= 2'b00;

        end
    end

    //////////////////////////////////////////////////////
    //              stage 2: FP comparison              //
    //////////////////////////////////////////////////////

    reg s2_valid;

    reg [1:0] raw_result;

    always_ff@(posedge clock)begin
        s2_valid <= s1_valid;
        if(sign_comp == 2'h0)begin
            if(exp_comp ==  2'h0) begin
                raw_result <= mant_comp;
            end else begin
                raw_result <= exp_comp;
            end
        end else begin
            raw_result <= sign_comp;
        end
    end


    //////////////////////////////////////////////////
    //       stage 3: special case handling         //
    //////////////////////////////////////////////////

    generate
        if(IEEE_COMPLIANT == "TRUE")begin : correctly_handle_special_values

            reg [31:0] s1_data_a;
            reg [31:0] s2_data_a;

            reg [31:0] s1_data_b;
            reg [31:0] s2_data_b;

            wire signed [7:0] s2_exponent_a;
            wire [22:0] s2_mantissa_a;
            wire signed [7:0] s2_exponent_b;
            wire [22:0] s2_mantissa_b;

            assign s2_exponent_a = s2_data_a[30:23];
            assign s2_exponent_b = s2_data_b[30:23];
            assign s2_mantissa_a = s2_data_a[22:0];
            assign s2_mantissa_b = s2_data_b[22:0];

            wire a_is_nan,b_is_nan;
            assign a_is_nan = (s2_exponent_a == 'hFF) && s2_mantissa_a != 0;
            assign b_is_nan = (s2_exponent_b == 'hFF) && s2_mantissa_b != 0;

            wire a_is_zero_n, b_is_zero_n;
            assign a_is_zero_n = s2_data_a == 'h80000000;
            assign b_is_zero_n = s2_data_b == 'h80000000;


            wire a_is_inf, a_is_n_inf, b_is_inf, b_is_n_inf;
            assign a_is_inf = (~s2_data_a[31]) &&  (s2_exponent_a == 'hFF) && s2_mantissa_a == 0;
            assign b_is_inf = (~s2_data_b[31]) &&  (s2_exponent_b == 'hFF) && s2_mantissa_b == 0;
            assign a_is_n_inf = (s2_data_a[31]) && (s2_exponent_a == 'hFF) && s2_mantissa_a == 0;
            assign b_is_n_inf = (s2_data_b[31]) && (s2_exponent_b == 'hFF) && s2_mantissa_b == 0;


            always_ff@(posedge clock)begin

                s1_data_a <= in_a.data;
                s2_data_a <= s1_data_a;

                s1_data_b <= in_b.data;
                s2_data_b <= s1_data_b;

                out.valid <= s2_valid;
                if( a_is_nan || b_is_nan)begin
                    out.data <= 3;
                end else if((a_is_zero_n && s2_data_b == 0) || ( s2_data_a == 0 && b_is_zero_n)) begin
                    out.data <= 0;
                end else if(a_is_inf & ~b_is_inf) begin
                    out.data <= 1;
                end else if(b_is_inf & ~a_is_inf) begin
                    out.data <= 2;
                end else if(a_is_n_inf & ~b_is_n_inf) begin
                    out.data <= 2;
                end else if(b_is_n_inf & ~a_is_n_inf) begin
                    out.data <= 1;
                end else begin
                    out.data <= raw_result;
                end
                out.dest <= s2_data_a;
                out.user <= s2_data_b;

            end
        end else begin : low_latency_mode

                assign out.valid = s1_valid;
                assign out.data = raw_result;
        end
    endgenerate


endmodule
