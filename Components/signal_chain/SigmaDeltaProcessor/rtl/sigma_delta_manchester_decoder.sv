// Copyright 2023 Filippo Savi
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


module sigma_delta_manchester_decoder(
    input wire clock,
    input wire bypass,
    input wire sd_data_in,
    output wire decoded_data
);
    reg rec_clk_del = 0;
    reg rec_data = 0;

    wire rec_clk;
    assign rec_clk = rec_data ^ sd_data_in;
    
    assign decoded_data = bypass ? sd_data_in : rec_data;
    
    always_ff@(posedge clock)begin
        rec_clk_del <= rec_clk;
    end

    always_ff@(posedge rec_clk)begin
        rec_data <= sd_data_in;
    end

endmodule