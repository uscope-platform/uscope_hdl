// Copyright 2025 Filippo Savi
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

module interpolating_enhancer #(
    parameter DATA_WIDTH = 16
)(
    input logic clock,
    input logic signed [DATA_WIDTH-1:0] cos,
    input logic signed [DATA_WIDTH-1:0] cos_next,
    input logic [1:0] selector,
    output logic signed [DATA_WIDTH-1:0] cos_out
);


    always_ff @(posedge clock)begin
        case (selector)
            0 : cos_out <= cos;
            1 : cos_out <= (cos*3 + cos_next)/4;
            2 : cos_out <= (cos + cos_next)/2;
            3 : cos_out = (cos + cos_next*3)/4;
        endcase
        
    end
    

endmodule