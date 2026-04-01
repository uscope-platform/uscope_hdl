// Copyright 2026 Filippo Savi
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


module encoder_emulator #(
    parameter PULSE_DURATION = 10,
    parameter PPR = 1000
)(
    input wire clock,
    input wire enable,
    output reg a,
    output reg b,
    output reg z
);


    reg [15:0] a_ctr = 0;
    reg [15:0] b_ctr = PULSE_DURATION/2;
    reg [15:0] z_ctr = 0;

    initial begin
        a = 0;
        b = 0;
        z = 0;
    end
    always @(posedge clock) begin
        if(enable)begin
            if(a_ctr == PULSE_DURATION-1)begin
                a_ctr <= 0;
                a <= ~a;
            end else begin
                a_ctr <=  a_ctr +1;
            end
        end
    end


    always @(posedge clock) begin
        if(enable)begin
            if(b_ctr == PULSE_DURATION-1)begin
                b_ctr <= 0;
                b <= ~b;
            end else begin
                b_ctr <=  b_ctr +1;
            end
        end
    end


    always @(posedge clock) begin
        if(enable)begin
            if(z_ctr >(PPR - PULSE_DURATION))begin
                z <= 1;
                if(z_ctr == PPR-1)begin
                    z_ctr <= 0;
                end
            end else begin
                z <= 0;
                z_ctr <= z_ctr +1;
            end
        end
    end



endmodule