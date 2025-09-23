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

module sine_lut #(
    parameter LUT_DEPTH   = 9,
    parameter INPUT_DATA_WIDTH = 16,
    parameter OUTPUT_WIDTH  = 16
)(
    input  wire [INPUT_DATA_WIDTH-1:0] angle,
    output reg [OUTPUT_WIDTH-1:0] cos,
    output reg [OUTPUT_WIDTH-1:0] cos_next
);

    localparam real STEP   = (2*3.14159265358979323846/4.0) / LUT_DEPTH;


    if ((INPUT_DATA_WIDTH-2) <$clog2(LUT_DEPTH)) begin
        $error("PARAMETER ERROR: THE INPUT DATA WIDTH NEEDS TO BE BIGGER THAN THE LUT ADDRESS");
    end


    wire [INPUT_DATA_WIDTH-1:0] angle_next;
    assign angle_next = angle + 1;
    logic [$clog2(LUT_DEPTH)-1:0] scaled_angle;
    logic [$clog2(LUT_DEPTH)-1:0] scaled_angle_next;
    assign scaled_angle = angle >> (INPUT_DATA_WIDTH-2-$clog2(LUT_DEPTH));
    assign scaled_angle_next = angle_next >> (INPUT_DATA_WIDTH-2-$clog2(LUT_DEPTH));
    
    logic [OUTPUT_WIDTH-1:0] rom [0:LUT_DEPTH-1];

    initial begin
        for (int i = 0; i < LUT_DEPTH; i++) begin
            real init_angle = i * STEP;
            real value = $cos(init_angle);
            int scaled = $rtoi(value * (1 << (OUTPUT_WIDTH-1))-1);
            rom[i] = scaled[OUTPUT_WIDTH-1:0];
        end
    end

    logic [1:0] sector;
    assign sector = angle[INPUT_DATA_WIDTH-1:INPUT_DATA_WIDTH-2];
    logic [1:0] sector_next;
    assign sector_next = angle_next[INPUT_DATA_WIDTH-1:INPUT_DATA_WIDTH-2];

    always_comb begin
        case (sector)
            0 : cos <= rom[scaled_angle];
            1 : cos <= -$signed(rom[(LUT_DEPTH-1)-scaled_angle]);
            2 : cos <= -$signed(rom[scaled_angle]);
            3 : cos <= rom[(LUT_DEPTH-1)-scaled_angle];
        endcase
        
        case (sector_next)
            0 : cos_next <= rom[scaled_angle_next];
            1 : cos_next <= -$signed(rom[(LUT_DEPTH-1)-scaled_angle_next]);
            2 : cos_next <= -$signed(rom[scaled_angle_next]);
            3 : cos_next <= rom[(LUT_DEPTH-1)-scaled_angle_next];
        endcase
    end



endmodule