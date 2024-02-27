// Copyright 2024 Filippo Savi
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

`timescale 10ns / 1ns
`include "interfaces.svh"

module ultra_buffer_memory #(parameter ADDRESS_WIDTH=12)(
    input wire clock,
    input wire reset,
    input wire write_enable,
    input wire [ADDRESS_WIDTH-1:0] write_address,
    input wire [ADDRESS_WIDTH-1:0] read_address,
    input wire [DATA_WIDTH-1:0] write_data,
    output reg [DATA_WIDTH-1:0] read_data
);

localparam MEMORY_DEPTH = (1<<ADDRESS_WIDTH);
localparam DATA_WIDTH = 72;


(* ram_style = "ultra" *)
reg [DATA_WIDTH-1:0] ring_buffer[MEMORY_DEPTH-1:0] =  '{default:0};        // Memory Declaration
   

always @ (posedge clock)begin
    if(write_enable) begin
        ring_buffer[write_address] <= write_data;
        
    end
    read_data <= ring_buffer[read_address];
end
				

endmodule