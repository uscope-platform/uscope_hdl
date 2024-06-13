// Copyright 2023 Filippo Savi
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

module sigma_delta_comparators #(
    parameter N_CHANNELS = 2
)(
    input wire clock,
    input wire reset,
    axi_stream.watcher data_in[N_CHANNELS],
    input wire signed [31:0] high_tresholds [N_CHANNELS-1:0],
    input wire signed [31:0] low_tresholds [N_CHANNELS-1:0],
    output reg [N_CHANNELS-1:0] high_outputs,
    output reg [N_CHANNELS-1:0] low_outputs,
    output wire combined_output
);


    wire signed [15:0] data [N_CHANNELS-1:0];

    genvar i;

    generate
        for(i = 0; i<N_CHANNELS; i++)begin

            assign data[i] = data_in[i].data;
        
            always_ff @(posedge clock) begin
                if(data_in[i].valid)begin
                    high_outputs[i] <= 0;
                    low_outputs[i] <= 0;
                    if(data[i] >= $signed(high_tresholds[i]))begin
                        high_outputs[i] <= 1;
                    end else if(data[i] <= $signed(low_tresholds[i]))begin
                        low_outputs[i] <= 1;
                    end
                end
            end
        end
        
        assign combined_output = |high_outputs || |low_outputs;
    endgenerate



endmodule