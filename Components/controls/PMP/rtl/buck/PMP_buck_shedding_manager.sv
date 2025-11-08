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

module PMP_buck_shedding_manager #(
    N_PHASES = 4
)(
    input wire clock,
    input wire reset,
    input wire [$clog2(N_PHASES)-1:0] n_phases,
    input wire [15:0] period,
    input wire [15:0] duty_in[N_PHASES-1:0],
    output reg [15:0] duty_out[N_PHASES-1:0]
);
  
    reg signed [15:0] duty_ff[N_PHASES-1:0]  = '{default:0};

    reg [$clog2(N_PHASES)-1:0] n_phases_del  = 0;
    reg [$clog2(N_PHASES)-1:0]  n_activations = 0;

    genvar j;


    always_ff @(posedge clock) begin
        n_phases_del <= n_phases;
        if(n_phases > n_phases_del) n_activations <= n_phases - n_phases_del;

        if(n_activations == 1) begin
            duty_ff[n_phases] <= $signed(duty_in[0]);
        end else if(n_activations ==2)begin
            duty_ff[n_phases] <= $signed(duty_in[0]);
            duty_ff[n_phases-1] <= $signed(duty_in[0]);
        end
        
        duty_out[0] <= duty_in[0];
        for(integer i = 1; i<N_PHASES; i++)begin
            // duty_ff is guaranteed to be non negative given how the control system workk
            // thus when the input duty is negative and larger than the ff saturate the output to 0
            if(($signed(duty_in[i]) +  duty_ff[i])<0) begin
                duty_out[i] <= 0;
            end else if(($signed(duty_in[i]) + duty_ff[i])>=period) begin
                duty_out[i] <= period-1;
            end else begin
                duty_out[i] <= $signed(duty_in[i]) + duty_ff[i];
            end
                
        end
    end



    
endmodule
