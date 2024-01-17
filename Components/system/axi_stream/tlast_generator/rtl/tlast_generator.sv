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

`timescale 10ns / 1ns
`include "interfaces.svh"

module tlast_generator_sv(
    input wire clock,
    input wire reset, 
    input wire disable_gen,
    input wire [15:0] period,
    output wire [15:0] current_sample,
    //input AXI stream
    axi_stream.slave data_in,
    axi_stream.master data_out
);


    reg [15:0] tlast_counter;
    assign current_sample = tlast_counter;
    assign data_in.ready = data_out.ready;

    always@(posedge clock)begin
        if(~reset)begin
            data_out.tlast <= 0;
            data_out.valid <= 0;
            tlast_counter <= 0;
        end else begin
            if(disable_gen)begin
                data_out.valid <= 0;
            end else begin
                data_out.valid <= data_in.valid;
            end
            data_out.data <= data_in.data;
            data_out.dest <= data_in.dest;

            if(data_in.valid)begin
                if(tlast_counter==period-1)begin
                    tlast_counter <= 0;
                    data_out.tlast <= 1;
                end else begin
                    tlast_counter <= tlast_counter+1;
                end
            end else begin
                data_out.tlast <= 0;
            end
        end
    end


endmodule
