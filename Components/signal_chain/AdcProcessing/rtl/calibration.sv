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

module calibration #(
    parameter DATA_PATH_WIDTH = 16,
    N_CHANNELS = 1,
    parameter [N_CHANNELS-1:0] OUTPUT_SIGNED = {N_CHANNELS{1'b1}}
    )(
    input wire clock,
    input wire reset,
    input wire signed [DATA_PATH_WIDTH-1:0] offset [N_CHANNELS-1:0],
    input wire [DATA_PATH_WIDTH-1:0] shift [N_CHANNELS-1:0],
    input wire shift_enable,
    axi_stream.slave data_in,
    axi_stream.master data_out
);

    wire signed [DATA_PATH_WIDTH-1:0] raw_data_out;
    reg signed [31:0] gain_corrected_data;
    reg signed [DATA_PATH_WIDTH-1:0] truncated_gain_corrected_data;

    
    assign data_in.ready = data_out.ready | ~reset ? 1 : 0;


    saturating_adder #(.DATA_WIDTH(DATA_PATH_WIDTH)) offset_adder(
        .a(data_in.data),
        .b(offset[data_in.dest]),
        .satp({1'b0,{DATA_PATH_WIDTH-1{1'b1}}}),
        .satn({OUTPUT_SIGNED[data_in.dest],{DATA_PATH_WIDTH-1{1'b0}}}),
        .out(raw_data_out)
    );

    always @(posedge clock)begin
        if(~reset) begin
            gain_corrected_data <= 0;
            truncated_gain_corrected_data <= 0;
            data_out.data <= 0;
            data_out.valid <=0;
        end else begin
            if(data_in.valid & data_out.ready) begin
                if(shift_enable) begin
                    data_out.data <= raw_data_out << shift[data_in.dest];
                end else begin
                    data_out.data <= raw_data_out;
                end
                data_out.dest <=data_in.dest;
                data_out.valid <=1;
            end else begin
                data_out.valid <=0;
            end
        end
    end


endmodule