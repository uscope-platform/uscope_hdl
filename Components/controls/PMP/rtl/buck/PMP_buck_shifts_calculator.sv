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
`include "interfaces.svh"

module PMP_buck_shifts_calculator #(
    N_PHASES = 4
)(
    input wire clock,
    input wire reset,
    input wire [4:0] n_phases,
    input wire [15:0] period,
    output reg [15:0] phase_shifts [N_PHASES-1:0]
);


    reg [16:0] divisors_table [N_PHASES-1:0];
    
    initial begin
        $readmemh("pmp_buck_divisors.mem", divisors_table);
    end

    enum reg [1:0] { 
        initialize_state = 0,
        idle_state = 1,
        calculation_state = 2
    } state = initialize_state;



    reg [3:0] phases_ctr = 0;  
    reg [3:0] n_phases_prev;
    reg [15:0] phase_advance;
    
    reg recalculate_phases = 0;

    wire [31:0] advance_ext; 
    assign advance_ext = divisors_table[n_phases-1]*period;

    always @(posedge clock) begin
        n_phases_prev <= n_phases;
        case(state)
            initialize_state :begin
                if(period != 0)begin
                    phase_advance <= advance_ext>>16;  
                    state <= calculation_state;
                end
            end
            idle_state:begin
                if(n_phases_prev != n_phases)begin
                    state <= calculation_state;
                    phase_advance <= advance_ext>>16;  
                end
            end
            calculation_state:begin
                phase_shifts[phases_ctr] = phase_advance*phases_ctr;
                if(phases_ctr == n_phases-1)begin
                    state <= idle_state;
                    phases_ctr <= 0;
                end else begin
                    phases_ctr <= phases_ctr +1; 
                end
            end
        endcase
    end



endmodule
