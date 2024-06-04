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
    input wire sd_data_in,
    input wire sd_clock_in,
    output reg decoded_data
);



    reg [1:0] wait_sample_point = 0;
    reg sd_clock_in_del = 0;
    always@(posedge clock)begin
        sd_clock_in_del <= sd_clock_in;
        if(sd_clock_in_del & !sd_clock_in) begin
            wait_sample_point <= 1;
        end
        if(wait_sample_point == 1)begin
            wait_sample_point <= 2;
        end
        if(wait_sample_point == 2)begin
            decoded_data <= sd_data_in;
            wait_sample_point <= 0;
        end
    end

  


endmodule