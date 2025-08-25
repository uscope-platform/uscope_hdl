
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
`include "interfaces.svh"

module fp_itf #(
    parameter FIXED_POINT_Q015 = 0,
    parameter INPUT_WIDTH = 16
) (
    input  logic clock,
    input  logic reset,
    axi_stream.slave in,
    axi_stream.master out
);

    axi_stream #(.DATA_WIDTH(INPUT_WIDTH+1), .USER_WIDTH(1)) stage_1(); // sign is mapped to user field;
    axi_stream #(.DATA_WIDTH(INPUT_WIDTH+1), .USER_WIDTH(1)) stage_2(); // sign is mapped to user field the index of the MSB is mapped to dest field;

    // -----------------------
    // Stage 1: Sign + Abs
    // -----------------------

    always_ff @(posedge clock) begin
        if (!reset) begin
            stage_1.valid <= 0;
        end else begin
            stage_1.valid <= in.valid;
            stage_1.user  <= in.data[INPUT_WIDTH-1];
           
            if(in.data[INPUT_WIDTH-1])begin
                stage_1.data <= (~in.data + 1'b1);
            end else begin
                stage_1.data <= in.data;
            end
        end
    end



    function  logic [$clog2(INPUT_WIDTH)-1:0] get_msb_index (input logic [31:0] value);
        
        integer i;
        logic [$clog2(INPUT_WIDTH)-1:0] msb = 0;
        for (i = 0; i < INPUT_WIDTH; i++)
            if (value[i]) msb = i;
        get_msb_index = msb;
    endfunction

    // -----------------------
    // Stage 2: Leading-One Detection
    // -----------------------
    
    always_ff @(posedge clock) begin
        if (!reset) begin
            stage_2.valid <= 0;
        end else begin
            stage_2.valid <= stage_1.valid;
            stage_2.user  <= stage_1.user;
            stage_2.data  <= stage_1.data;
            stage_2.dest  <= get_msb_index(stage_1.data);
        end
    end

    // -----------------------
    // Stage 3: Exponent + Mantissa + Pack
    // -----------------------

    logic [7:0] exponent;
    logic [7:0] pre_rounded_exponent;

    if(FIXED_POINT_Q015)begin
        assign exponent = 127 + (stage_2.dest - 15);
    end else begin
        assign exponent = 127 + stage_2.dest;
    end
    
    logic [38:0] shifted;
    assign shifted = stage_2.dest<23 ? stage_2.data << (23 - stage_2.dest) : stage_2.data >> (stage_2.dest - 23);

    logic round_up;
    logic [22:0] mantissa;
    logic [22:0] pre_rounded_mantissa;
    assign pre_rounded_mantissa = shifted[22:0] +1'b1;

    assign pre_rounded_exponent = exponent + 1'b1;

    assign mantissa = shifted[22:0];

    rounding_engine #(
        .DATA_WIDTH(INPUT_WIDTH)
    ) rounder (
        .data_in(stage_2.data),
        .msb_index(stage_2.dest),
        .mantissa_lsb(shifted[0]),
        .round_up(round_up)
    );
    

    always_ff @(posedge clock) begin
        if (!reset) begin
            out.valid <= 0;
        end else begin
            out.valid <= stage_2.valid;

            if (stage_2.data == 0) begin
                out.data <= 32'h0000_0000; // zero
            end else begin
                if(round_up) begin
                    if(mantissa == 23'h7FFFFF) begin
                        out.data <= {stage_2.user, pre_rounded_exponent, 23'b0};
                    end else begin
                        out.data <= {stage_2.user, exponent,pre_rounded_mantissa};
                    end
                end else begin
                    out.data <= {stage_2.user, exponent, mantissa};
                end

            end
        end
    end

endmodule
