// Copyright 2021 University of Nottingham Ningbo China
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

module calibration #(parameter DATA_PATH_WIDTH = 16)(
    input wire clock,
    input wire reset,
    input wire in_valid,
    output wire in_ready,
    input wire pipeline_flush,
    input wire [2:0] cal_address,
    input wire [15:0] cal_data,
    input wire cal_we,
    input wire signed [DATA_PATH_WIDTH-1:0] data_in,
    input wire gain_enable,
    output reg signed [DATA_PATH_WIDTH-1:0] data_out,
    output reg out_valid,
    input wire out_ready
);

    wire signed [DATA_PATH_WIDTH-1:0] raw_data_out;
    reg signed [31:0] gain_corrected_data;
    reg signed [DATA_PATH_WIDTH-1:0] truncated_gain_corrected_data;
    reg signed [DATA_PATH_WIDTH-1:0] coefficients [1:0];
    reg [2:0] shift;
    
    assign in_ready = out_ready | ~reset ? 1 : 0;

    saturating_adder #(.DATA_WIDTH(DATA_PATH_WIDTH)) offset_adder(
        .a(data_in),
        .b(coefficients[1]),
        .satp({1'b0,{DATA_PATH_WIDTH-1{1'b1}}}),
        .satn({1'b1,{DATA_PATH_WIDTH-1{1'b0}}}),
        .out(raw_data_out)
    );

    always @(posedge clock)begin
        if(~reset | pipeline_flush) begin
            gain_corrected_data <= 0;
            truncated_gain_corrected_data <= 0;
            data_out <= 0;
            out_valid <=0;
        end else begin
            if(in_valid & out_ready) begin
                if(gain_enable) begin
                    data_out <= raw_data_out << shift;
                end else begin
                    data_out <= raw_data_out;
                end
                out_valid <=1;
            end else begin
                out_valid <=0;
            end
        end
    end



  always @(posedge clock) begin
        if(~reset)begin
            shift <= 0;
            coefficients[0] <= 0;
            coefficients[1] <= 0;
        end else begin
            if(cal_we) begin
                case (cal_address)
                    0: coefficients[0] <= $signed(cal_data);  
                    1: coefficients[1] <= $signed(cal_data);
                    2: shift <= cal_data[2:0];
                endcase
            end 
        end
    end

endmodule