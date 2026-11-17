// Copyright 2026 University of Nottingham
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

module enable_generator_tb_sync #(
    N_ENABLES = 1,
    ENABLE = 0
)(
    input  wire                 clock,
    input  wire                 bypass,
    input  wire                 ext_timebase,
    input  wire [N_ENABLES-1:0] enable_in,
    output reg  [N_ENABLES-1:0] enable_out
);

    reg [N_ENABLES-1:0] prev_enable_in;
    reg [N_ENABLES-1:0] synchronized_out;

    always_ff @(posedge clock) begin
        if (bypass) begin
            synchronized_out <= {N_ENABLES{ext_timebase}};
        end else begin
            prev_enable_in <= enable_in;
            synchronized_out   <= enable_in & ~prev_enable_in;
        end
    end

    assign enable_out = (ENABLE == 1) ? synchronized_out : enable_in;

endmodule
