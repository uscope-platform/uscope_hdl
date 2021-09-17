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

module saturating_adder_tb ();

    reg signed [15:0] a = 0;
    reg signed [15:0] b = 0;
    wire signed [15:0] out = 0;

    saturating_adder tb(
        .a(a),
        .b(b),
        .satp(3277),
        .satn(-3277),
        .out(out)
    );



    initial begin
        a <=0;
        b <=0;
      #5 a <= 32767;
      #1 b <= 32767;
      #10 a <= -32767;
      #1  b <= -32767;
    end

endmodule