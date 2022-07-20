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

`timescale 10ns / 1ns
`include "interfaces.svh"

module batcher_sorter_8_serial #(
    parameter DATA_WIDTH = 32
)(
    input wire clock,
    input wire reset,
    input wire [3:0] chunk_size,
    axi_stream.slave data_in,
    input wire data_out_ready,
    output reg [DATA_WIDTH-1:0] data_out [7:0],
    output reg data_out_valid
);
    
    assign data_in.ready = data_out_ready;
    
    reg [2:0] input_buffer_index = 0;
    reg [DATA_WIDTH-1:0] input_buffer_a [7:0];
    reg [DATA_WIDTH-1:0] input_buffer_b [7:0];
    reg sorter_start = 0;
    reg buffer_select = 0;
    
    initial begin
        for (integer i = 0; i < 8; i = i + 1) begin
            input_buffer_a[i] = 0;
            input_buffer_b[i] = 0;
        end
    end


    wire [DATA_WIDTH-1:0] selected_input_buffer [7:0];
    assign selected_input_buffer = ~buffer_select ? input_buffer_b : input_buffer_a;



    always_ff @(posedge clock)begin
        sorter_start <= 0;
        if(data_in.valid)begin
            if(buffer_select) begin
                input_buffer_b[input_buffer_index] <= data_in.data;
            end else begin
                input_buffer_a[input_buffer_index] <= data_in.data;
            end
 
            if(input_buffer_index == chunk_size-1)begin
                input_buffer_index <= 0;
                buffer_select <= ~buffer_select;
                sorter_start <= 1;
            end else begin
                input_buffer_index <= input_buffer_index + 1;
            end
        end

        if(data_out_valid)begin
            for(int i = 0; i<8; i=i+1) begin
                if(buffer_select)begin
                    input_buffer_a[i] <= 0;
                end else begin
                    input_buffer_b[i] <= 0;
                end
            end
            data_out <= data_out_ub;
        end
        data_out_valid <= data_out_valid_ub;
    end


    wire [DATA_WIDTH-1:0] data_out_ub [7:0];
    wire data_out_valid_ub;

    batcher_sorter_8 #(
        .DATA_WIDTH(DATA_WIDTH)
    ) parallel_sorter (
        .clock(clock),
        .reset(reset),
        .data_in(selected_input_buffer),
        .data_in_valid(sorter_start),
        .data_out(data_out_ub),
        .data_out_valid(data_out_valid_ub)
    );



endmodule