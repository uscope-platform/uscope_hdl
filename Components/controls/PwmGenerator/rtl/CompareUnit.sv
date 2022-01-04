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

module CompareUnit  #(parameter COUNTER_WIDTH = 16)(
    input wire         clock,
    input wire         reset,
    input wire  [COUNTER_WIDTH-1:0] counterValue,
    input wire         counter_stopped,
    input wire         we,
    input wire  [2:0]  adress,
    input wire  [COUNTER_WIDTH-1:0] dataIn,
    input wire         reload_compare,
    output reg [2:0] matchHigh,
    output reg [2:0] matchLow
);


    reg [COUNTER_WIDTH-1:0] shadow_registers [5:0];
    reg [COUNTER_WIDTH-1:0] working_registers [5:0];

	integer i;

always @(posedge clock) begin : shadow_update_logic
    if(~reset)begin
            for(i = 0; i<6; i=i+1) begin
                shadow_registers[i] <= {COUNTER_WIDTH{1'b1}}*(i%2);
                working_registers[i] <= {COUNTER_WIDTH{1'b1}}*(i%2);
            end
    end else begin
        if(counter_stopped) begin
            if(we && adress<6) begin 
                working_registers[adress] <= dataIn;
                shadow_registers[adress] <= dataIn;
            end else if(we && adress==6) begin
                working_registers[0] <= dataIn;
                working_registers[1] <= dataIn;
                working_registers[2] <= dataIn;
                shadow_registers[0] <= dataIn;
                shadow_registers[1] <= dataIn;
                shadow_registers[2] <= dataIn;
            end else if(we && adress==7) begin
                working_registers[3] <= dataIn;
                working_registers[4] <= dataIn;
                working_registers[5] <= dataIn;
                shadow_registers[3] <= dataIn;
                shadow_registers[4] <= dataIn;
                shadow_registers[5] <= dataIn;
            end
        end else begin
            if(we && adress<6) begin 
                shadow_registers[adress] <= dataIn;
            end else if(we && adress==6) begin
                shadow_registers[0] <= dataIn;
                shadow_registers[1] <= dataIn;
                shadow_registers[2] <= dataIn;
            end else if(we && adress==7) begin
                shadow_registers[3] <= dataIn;
                shadow_registers[4] <= dataIn;
                shadow_registers[5] <= dataIn;
            end
            if(reload_compare) begin 
                working_registers[0][COUNTER_WIDTH-1:0] <= shadow_registers[0][COUNTER_WIDTH-1:0];
                working_registers[1][COUNTER_WIDTH-1:0] <= shadow_registers[1][COUNTER_WIDTH-1:0];
                working_registers[2][COUNTER_WIDTH-1:0] <= shadow_registers[2][COUNTER_WIDTH-1:0];
                working_registers[3][COUNTER_WIDTH-1:0] <= shadow_registers[3][COUNTER_WIDTH-1:0];
                working_registers[4][COUNTER_WIDTH-1:0] <= shadow_registers[4][COUNTER_WIDTH-1:0];
                working_registers[5][COUNTER_WIDTH-1:0] <= shadow_registers[5][COUNTER_WIDTH-1:0];
            end
        end
    end
end




    always @(posedge clock) begin : compare_logic_proper
        if (~reset) begin
            matchLow <= 0;
            matchHigh <= 0;
        end else begin
            if(counterValue < working_registers[0]) matchLow[0] <= 1;
            else matchLow[0] <= 0;
            if(counterValue < working_registers[1]) matchLow[1] <= 1;
            else matchLow[1] <= 0;
            if(counterValue < working_registers[2]) matchLow[2] <= 1;
            else matchLow[2] <= 0;
            if(counterValue > working_registers[3]) matchHigh[0] <= 1;
            else matchHigh[0] <= 0;
            if(counterValue > working_registers[4]) matchHigh[1] <= 1;
            else matchHigh[1] <= 0;
            if(counterValue > working_registers[5]) matchHigh[2] <= 1;
            else matchHigh[2] <= 0;
        end
    end


endmodule