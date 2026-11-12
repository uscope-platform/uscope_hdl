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
`timescale 10 ns / 1 ns

module CORDIC_core#(
    parameter integer RESOLUTION = 16,
    parameter integer GUARD_BITS = 3,
    parameter bit OUTPUT_0_2PI = 1'b0 // 0: angle in [-PI, PI) (sign extended), 1: angle in [0, 2*PI) (zero extended)
)(
    input wire clock,
    input wire reset,
    axi_stream.slave initial_condition,
    axi_stream.master out
);

    typedef logic [RESOLUTION-1:0] atan_lut_t [RESOLUTION-1:0];
    function automatic atan_lut_t generate_atan_lut();
        real angle_rad;
        real scale_factor;
        
        // Scale factor to convert radians to fixed-point integer representation
        // Full scale: PI = 2**(RESOLUTION-1), matching the quadrant selector
        scale_factor = (1 << (RESOLUTION - 1)) / 3.14159265358979323846;

        for (int i = 0; i < RESOLUTION; i++) begin
            // math.atan(2 ** -i)
            angle_rad = $atan(1.0 / (1 << i)); 
            
            // Convert to fixed-point representation
            generate_atan_lut[i] = $rtoi($floor(angle_rad * scale_factor + 0.5));
        end
    endfunction
    localparam atan_lut_t ATAN_LUT = generate_atan_lut();

    localparam WORK_WIDTH = RESOLUTION + GUARD_BITS;

    reg [$clog2(RESOLUTION)-1:0] step_counter = 0;
    reg signed [WORK_WIDTH-1:0] x_int;
    reg signed [WORK_WIDTH-1:0] y_int;
    reg signed [WORK_WIDTH-1:0] z_int;


    enum reg [1:0] { 
        idle_state,
        processing_state
    } state = idle_state;

    assign initial_condition.ready = out.ready && state == idle_state;

    wire d_pos = (y_int < 0);

    wire signed [WORK_WIDTH-1:0] x_shift = x_int >>> step_counter;
    wire signed [WORK_WIDTH-1:0] y_shift = y_int >>> step_counter;

    wire signed [WORK_WIDTH-1:0] x_next = d_pos ? (x_int - y_shift) : (x_int + y_shift);
    wire signed [WORK_WIDTH-1:0] y_next = d_pos ? (y_int + x_shift) : (y_int - x_shift);
    wire signed [WORK_WIDTH-1:0] z_next = d_pos ? (z_int - ATAN_LUT[step_counter]) : (z_int + ATAN_LUT[step_counter]);

    // Angle is PI = 2**(RESOLUTION-1) full scale, so the same bits are either
    // two's complement [-PI, PI) or unsigned [0, 2*PI)
    localparam integer OUT_WIDTH = out.DATA_WIDTH;
    wire [RESOLUTION-1:0] z_out = z_next[RESOLUTION-1:0];

    always_ff @(posedge clock) begin

        out.valid <= 0; 
        case (state)
            idle_state: begin
                if (initial_condition.valid && initial_condition.ready) begin
                    state <= processing_state;
                    x_int  <= signed'(initial_condition.data[15:0]);
                    y_int <= signed'(initial_condition.data[31:16]);
                    z_int <= signed'(initial_condition.user);
                    step_counter <= 0;
                end
            end 
            processing_state: begin
                
                step_counter <= step_counter + 1;
                x_int <= x_next;
                y_int <= y_next;
                if(step_counter == RESOLUTION-1)begin
                    state <= idle_state;
                    out.data <= OUTPUT_0_2PI ? OUT_WIDTH'(z_out) : OUT_WIDTH'($signed(z_out));
                    out.valid <= 1;
                end else begin
                    z_int <= z_next;
                end
            end 
        endcase
    end

endmodule
    
        