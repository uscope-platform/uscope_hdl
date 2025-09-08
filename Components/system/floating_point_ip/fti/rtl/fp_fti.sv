
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
// See the License for the specific language governing prmissions and
// limitations under the License.
`timescale 10 ns / 1 ns
`include "interfaces.svh"

module fp_fti #(
    parameter FIXED_POINT_Q015 = 0
) (
    input wire clock,
    input wire reset,
    axi_stream.slave in,
    axi_stream.master out
);

assign in.ready = 1;

reg signed [7:0] exponent = 0;
reg [23:0] mantissa = 0;
reg subnormal = 0;
reg sign = 0;

reg mantissa_is_zero = 0;
reg stage_1_valid = 0;
reg stage_1_sign = 0;

////////////////////////////////////////////////////////
//           STAGE 1: EXTRACT FP COMPONENTS           //
////////////////////////////////////////////////////////

always_ff @(posedge clock)begin
    stage_1_valid <= in.valid;
    if(in.valid)begin
        mantissa <= {1, in.data[22:0]};
        exponent <=  $signed({1'b0, in.data[30:23]})-9'sd127;
        subnormal <= in.data[30:23] == 0;
        sign <= in.data[31];
        mantissa_is_zero <= (in.data[22:0] == 0);
    end
end


////////////////////////////////////////////////////////
//          STAGE 2: SHIFT THE DECIMAL POINT          //
////////////////////////////////////////////////////////

reg stage_2_valid = 0;
reg stage_2_sign = 0;
reg [23:0] stage_2_mantissa = 0;

wire overflow;
assign overflow = (exponent > 31) || (exponent == 31 && (sign || ~mantissa_is_zero));

reg [out.DATA_WIDTH-1:0] raw_shifted_data;
reg signed [7:0] lsb_index;


always_ff @(posedge clock)begin
    stage_2_valid <= stage_1_valid;
    stage_2_mantissa <= mantissa;
    stage_2_sign <= sign;
    if(subnormal)begin
        raw_shifted_data <= 0;
    end else if(overflow)begin
        raw_shifted_data <= sign ? {1, {(out.DATA_WIDTH-1){1'b0}}}:  {(out.DATA_WIDTH-1){1'b1}};
    end else begin
        if($signed(exponent)<0) begin
            raw_shifted_data <= 0;
        end else if(exponent<23)begin
            raw_shifted_data <= mantissa>>(23-exponent);
        end else begin
            raw_shifted_data <= mantissa << (exponent-23);
        end
    end
    
    if (($signed(exponent) < -1) || ($signed(exponent) >= 23)) begin
        lsb_index <= 8'sd0;
    end else begin
        lsb_index <= 23 - exponent;
    end
end

////////////////////////////////////////////////////////
//           STAGE 3: ROUND TO NEAREST EVEN           //
////////////////////////////////////////////////////////



    wire round_up;
    fti_rounding_engine #(
        .DATA_WIDTH(24)
    ) rounder (
        .data_in(stage_2_mantissa),
        .lsb_index(lsb_index),
        .mantissa_lsb(raw_shifted_data[0]),
        .round_up(round_up)
    );



always_ff @(posedge clock)begin
    out.data <= stage_2_sign ? -(raw_shifted_data+round_up) : raw_shifted_data+round_up;
    out.valid <= stage_2_valid;
end

endmodule
