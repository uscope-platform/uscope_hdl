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

module ultra_buffer #(parameter ADDRESS_WIDTH=12, IN_DATA_WIDTH=32, DEST_WIDTH=16, USER_WIDTH=16)(
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



enum reg [2:0] { 
    pre_trigger = 0,
    acquisition = 1,
    wait_output = 2,
    wait_reg = 3,
    readout = 4,
    empty_pipeline = 5
} state = pre_trigger;



reg [ADDRESS_WIDTH-1:0] mem_counter = 0;
wire [USER_WIDTH-1:0] out_user;
wire [DEST_WIDTH-1:0] out_dest;
wire [IN_DATA_WIDTH-1:0] out_data;   
reg [ADDRESS_WIDTH-1:0]  read_address = 0;     // Read  Address

ultra_buffer_memory #(
    .ADDRESS_WIDTH(ADDRESS_WIDTH)
) inner_mem(
    .clock(clock),
    .reset(reset),
    .write_enable(in.valid && (state == pre_trigger || state == acquisition)),
    .write_address(mem_counter),
    .read_address(read_address),
    .write_data({in.user[USER_WIDTH-1:0], in.dest[DEST_WIDTH-1:0], in.data[IN_DATA_WIDTH-1:0]}),
    .read_data({out_user, out_dest, out_data})
);


initial begin
    out.data <= 0;
    out.user <= 0;
    out.dest <= 0;
end

reg [ADDRESS_WIDTH-1:0] initial_address = 0;

wire [ADDRESS_WIDTH-1:0] final_aquisition;
assign final_aquisition = initial_address-1;

always @(posedge clock) begin
    case (state)
        pre_trigger: begin
            full <= 0;
            in.ready <= 1;
            out.tlast <= 0;
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
                if(mem_counter == final_aquisition) begin
                    state <= wait_output;
                    read_address <= initial_address;
                    in.ready <= 0;
                    full <= 1;
                end else begin
                    mem_counter<= mem_counter +1;
                end
            end
        end
        wait_output: begin
            if(out.ready)begin
                full <= 0;
                read_address <= read_address + 1;
                state <= readout;
            end 
        end 
        readout: begin
            full <= 0;
            if(read_address == final_aquisition)begin
                state <= empty_pipeline;
            end
            out.user <= out_user;
            out.data <= out_data;
            out.dest <= out_dest;
            out.valid <= 1;
            read_address <= read_address + 1;
        end
        empty_pipeline:begin
            state <= pre_trigger;
            out.valid <= 1;
            out.tlast <= 1;
            out.user <= out_user;
            out.data <= out_data;
            out.dest <= out_dest;
        end
    endcase
end
		
                    				

endmodule