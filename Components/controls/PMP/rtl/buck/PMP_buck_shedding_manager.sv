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

module PMP_buck_shedding_manager #(
    N_PHASES = 4
)(
    input wire clock,
    input wire reset,
    input wire [$clog2(N_PHASES)-1:0] n_phases,
    input wire [15:0] duty_in[N_PHASES-1:0],
    output reg [15:0] duty_out[N_PHASES-1:0]
);

    reg [15:0] duty_ff[N_PHASES-1:0]  = '{default:0};
    reg [$clog2(N_PHASES)-1:0] n_phases_del  = '{default:0};

    wire [$clog2(N_PHASES)-1:0] n_activations = n_phases - n_phases_del;

    always_ff @(posedge clock) begin
        n_phases_del <= n_phases;
        if(n_phases >= n_phases_del)begin
            duty_ff[n_phases] <= duty_in[n_phases];
        end
        if(n_activations == 1) begin
            duty_ff[n_phases] <= duty_in[n_phases];
        end else if(n_activations ==2)begin
            duty_ff[n_phases] <= duty_in[n_phases];
            duty_ff[n_phases-1] <= duty_in[n_phases-1];
        end
        duty_out[0] <= duty_in[0];
        for(integer i = 1; i<N_PHASES+1; i++)begin

            duty_out[i] <= duty_ff[i] + duty_in[i];
        end
    end



    
endmodule
