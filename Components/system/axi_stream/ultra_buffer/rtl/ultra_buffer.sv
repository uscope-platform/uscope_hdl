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

module ultra_buffer #(parameter DATA_WIDTH = 32,USER_WIDTH = 32, DEST_WIDTH = 32, FIFO_DEPTH = 16)(
    input wire clock,
    input wire reset,
    input wire enable,
    input wire trigger,
    input wire [11:0] trigger_point,
    axi_stream.slave in,
    axi_stream.master out
);

localparam ADDRESS_WIDTH = 12;
localparam MEMORY_DEPTH = (1<<ADDRESS_WIDTH);
localparam DATA_WIDTH = 72;
parameter N_PIPE = 3;   // Number of pipeline Registers

reg [ADDRESS_WIDTH-1:0] write_address;     // Write Address
reg [ADDRESS_WIDTH-1:0]  read_address;     // Read  Address


(* ram_style = "ultra" *)
reg [DATA_WIDTH-1:0] ring_buffer[MEMORY_DEPTH-1:0];        // Memory Declaration

reg [DATA_WIDTH-1:0] output_reg;   

reg en_pipeline[N_PIPE:0];
reg [DATA_WIDTH-1:0] output_pipeline[N_PIPE-1:0];    // Pipelines for memory

always @ (posedge clock)begin
    if(in.valid) begin
        ring_buffer[write_address] <= {in.data, in.dest, in.user};
    end
    
    output_reg <= ring_buffer[read_address];
end


// RAM output data goes through a pipeline.
always @ (posedge clock) begin
    output_pipeline[0] <= output_reg;
end    

always @ (posedge clock) begin
    for (i = 0; i < N_PIPE-1; i = i+1)begin
        output_pipeline[i+1] <= output_pipeline[i];
    end
end      

always @ (posedge clock) begin
    {out.data, out.dest, out.user} <= output_pipeline[N_PIPE-1];
end


enum reg [1:0] { 
    pre_trigger = 0,
    acquisition = 1,
    stopped = 2
} state = pre_trigger;

reg [11:0] mem_counter = 0;
reg [11:0] final_address;
always @(posedge clock) begin
    case (state)
        pre_trigger: begin
            if(trigger)begin
                state <= acquisition;
                final_address <= mem_counter + MEMORY_DEPTH;
            end
            mem_counter <= mem_counter + 1;
        end
        acquisition: begin
            if(mem_counter == final_address) begin
                state <= stopped;
            end else begin
                mem_counter<= mem_counter +1;
            end
        end
        stopped: begin
            
        end 
        default: 
    endcase
end
		
                    				

endmodule