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

module ultra_buffer #(parameter ADDRESS_WIDTH=12)(
    input wire clock,
    input wire reset,
    input wire enable,
    input wire trigger,
    input wire [11:0] trigger_point,
    output reg full,
    axi_stream.slave in,
    axi_stream.master out
);

localparam MEMORY_DEPTH = (1<<ADDRESS_WIDTH);
localparam DATA_WIDTH = 72;
parameter N_PIPE = 3;   // Number of pipeline Registers

wire [ADDRESS_WIDTH-1:0] write_address;     // Write Address
reg [ADDRESS_WIDTH-1:0]  read_address;     // Read  Address


(* ram_style = "ultra" *)
reg [DATA_WIDTH-1:0] ring_buffer[MEMORY_DEPTH-1:0];        // Memory Declaration

reg [DATA_WIDTH-1:0] output_reg;   

reg [DATA_WIDTH-1:0] output_pipeline[N_PIPE-1:0];    // Pipelines for memory

always @ (posedge clock)begin
    if(in.valid && (state == pre_trigger || state == acquisition)) begin
        ring_buffer[write_address] <= {in.data, in.dest, in.user};
    end
    
    output_reg <= ring_buffer[read_address];
end


// RAM output data goes through a pipeline.
always @ (posedge clock) begin
    output_pipeline[0] <= output_reg;
end    

always @ (posedge clock) begin
    for (integer i = 0; i < N_PIPE-1; i = i+1)begin
        output_pipeline[i+1] <= output_pipeline[i];
    end
end      

assign write_address = mem_counter;


enum reg [2:0] { 
    pre_trigger = 0,
    acquisition = 1,
    wait_output = 2,
    fill_read_pipeline = 3,
    readout = 4,
    empty_pipeline = 5
} state = pre_trigger;

reg [ADDRESS_WIDTH-1:0] mem_counter = 0;
reg [ADDRESS_WIDTH-1:0] initial_address = 0;
reg [ADDRESS_WIDTH-1:0] final_address = 0;
reg[3:0] fill_ctr;
always @(posedge clock) begin
    case (state)
        pre_trigger: begin
            full <= 0;
            out.valid <= 0;
            if(trigger)begin
                state <= acquisition;
                initial_address <= mem_counter - trigger_point;
            end
            if(in.valid)begin
                mem_counter <= mem_counter + 1;
            end
        end 
        acquisition: begin
            if(in.valid)begin
                if(mem_counter == initial_address-1) begin
                    state <= wait_output;
                    full <= 1;
                end else begin
                    mem_counter<= mem_counter +1;
                end
            end

        end
        wait_output: begin
            if(out.ready)begin
                full <= 0;
                read_address <= initial_address;
                fill_ctr <= 0;
                state <= fill_read_pipeline;
            end
        end 
        fill_read_pipeline:begin
            if(fill_ctr == N_PIPE)begin
                state <= readout;
            end else begin
                fill_ctr <= fill_ctr + 1;
            end
            read_address <= read_address + 1;
        end
        readout: begin
            if(read_address == initial_address-1)begin
                state <= empty_pipeline;
            end
            {out.data, out.dest, out.user} <= output_pipeline[N_PIPE-1];
            out.valid <= 1;
            read_address <= read_address + 1;
        end
        empty_pipeline:begin
             if(fill_ctr == N_PIPE*2)begin
                state <= pre_trigger;
            end else begin
                fill_ctr <= fill_ctr + 1;
            end
            out.valid <= 1;
            {out.data, out.dest, out.user} <= output_pipeline[N_PIPE-1];
        end
    endcase
end
		
                    				

endmodule