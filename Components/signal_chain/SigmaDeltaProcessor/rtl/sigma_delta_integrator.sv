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

module sd_integrator #(
    parameter DATA_PATH_WIDTH = 16
)(
    input wire clock,
    input wire reset,
    input wire data_clock,
    input wire  [DATA_PATH_WIDTH-1:0] data_in,
    output wire [DATA_PATH_WIDTH-1:0] data_out
);


    reg [DATA_PATH_WIDTH-1:0] integrator_memory = 0;
    assign data_out = integrator_memory;
    reg data_clock_del = 0;

    always @(posedge clock) begin
        if(~reset) begin
            integrator_memory <= 0;
            data_clock_del <= 0;
        end else begin
            data_clock_del <= data_clock;
            if(~data_clock && data_clock_del)begin
                integrator_memory <= integrator_memory + data_in;
            end
        end
    end

endmodule