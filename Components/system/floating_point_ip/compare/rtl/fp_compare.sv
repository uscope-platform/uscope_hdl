
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

module fp_compare (
    input wire clock,
    axi_stream.slave in_a,
    axi_stream.slave in_b,
    axi_stream.master out
);


    
  
    
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


    reg [1:0] exp_comp;
    reg [1:0] mant_comp;
    reg [1:0] sign_comp;

    always_ff@(posedge clock)begin
        if(in_a.valid && in_b.valid) begin
            if(exponent_a > exponent_b) exp_comp <= 2'b10;
            else if(exponent_a < exponent_b) exp_comp <= 2'b01;
            else exp_comp <= 2'b00;

            if(mantissa_a > mantissa_b) mant_comp <= 2'b10;
            else if(mantissa_a < mantissa_b) mant_comp <= 2'b01;
            else mant_comp <= 2'b00;

            if(~sign_a && sign_b) sign_comp <= 2'b10;
            else if(sign_a && ~sign_b) sign_comp <= 2'b01;
            else sign_comp <= 2'b00;

        end
    end

    //////////////////////////////////////////////////////
    //              stage 2: FP comparison              //
    //////////////////////////////////////////////////////
    

    reg [1:0] raw_result;

    always_ff@(posedge clock)begin
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


    always_ff@(posedge clock)begin
        out.data <= raw_result;
    end

    


    reg [2:0] pipeline_valid;
    assign out.valid = pipeline_valid[2];


    always_ff@(posedge clock)begin
        pipeline_valid <= {pipeline_valid[1:0], in_a.valid && in_b.valid};
    end
endmodule
