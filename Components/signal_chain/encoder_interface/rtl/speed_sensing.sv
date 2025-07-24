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

module speed_sensing #(
    parameter COUNTER_WIDTH = 24
)(
    input wire clock,
    input wire reset,
    input wire z,
    input wire sample,
    input wire [31:0] output_destination,
    output wire [31:0] speed_out,
    axi_stream.master speed
);

    reg [COUNTER_WIDTH-1:0] frequency_counter = 0;
    reg [COUNTER_WIDTH-1:0] speed_register;
    reg prev_z;
    reg measurement_valid = 0;
    
    assign speed_out = speed_register;

    always_ff @( posedge clock) begin
        prev_z <= z;
        frequency_counter <= frequency_counter+1;
        if(z & ~prev_z)begin
            if(measurement_valid)begin
                speed_register  <= frequency_counter;
            end
            frequency_counter <= 0;
            measurement_valid <= 1;
        end
    end


    always_ff @(posedge clock) begin

        speed.valid <= 0;
        if(sample)begin
            speed.data <= speed_register;
            speed.dest <= output_destination;
            speed.valid <= 1;
        end
    end
    
endmodule
