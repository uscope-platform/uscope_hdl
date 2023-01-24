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
`include "interfaces.svh"

module CompareUnit  #(
    parameter COUNTER_WIDTH = 16,
    N_CHANNELS = 4
)(
    input wire         clock,
    input wire         reset,
    input wire [COUNTER_WIDTH-1:0] counterValue,
    input wire         counter_stopped,
    input wire [COUNTER_WIDTH-1:0] comparator_tresholds [N_CHANNELS*2-1:0],
    input wire         reload_compare,
    output reg [N_CHANNELS-1:0] matchHigh,
    output reg [N_CHANNELS-1:0] matchLow
);

    reg [COUNTER_WIDTH-1:0] working_registers [N_CHANNELS*2-1:0];

    always @(posedge clock) begin : shadow_update_logic
        if(counter_stopped) begin
            for(integer i = 0; i < 2*N_CHANNELS; i = i+1) begin
                working_registers[i][COUNTER_WIDTH-1:0] <= comparator_tresholds[i][COUNTER_WIDTH-1:0];
            end
        end else begin
            if(reload_compare) begin 
                for(integer i = 0; i < 2*N_CHANNELS; i = i+1) begin
                    working_registers[i][COUNTER_WIDTH-1:0] <= comparator_tresholds[i][COUNTER_WIDTH-1:0];
                end
            end
        end
    end

    always @(posedge clock) begin : compare_logic_proper
        if (~reset) begin
            matchLow <= 0;
            matchHigh <= 0;
        end else begin
            for(integer i = 0; i < N_CHANNELS; i = i+1) begin
                if(counterValue < working_registers[i]) matchLow[i] <= 1;
                else matchLow[i] <= 0;
            end
                        
            for(integer i = 0; i < N_CHANNELS; i = i+1) begin
                if(counterValue > working_registers[N_CHANNELS+i]) matchHigh[i] <= 1;
                else matchHigh[i] <= 0;
            end

        end
    end


endmodule