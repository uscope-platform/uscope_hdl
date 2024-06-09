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

module ultra_buffer #(parameter ADDRESS_WIDTH=13, DATA_WIDTH=32, DEST_WIDTH=16, USER_WIDTH=16)(
    input wire clock,
    input wire reset,
    input wire enable,
    input wire trigger,
    input wire [11:0] trigger_point,
    output reg full,
    axi_stream.slave in,
    axi_stream.master out
);

    reg [DATA_WIDTH-1:0] write_data = 0;
    reg [DATA_WIDTH-1:0] read_data = 0;
    reg [ADDRESS_WIDTH-1:0] write_address = 0;
    reg [ADDRESS_WIDTH-1:0] read_address = 0;
    reg registerd_write = 0;
    reg write_enabled = 0;


    localparam MEMORY_DEPTH = (1<<ADDRESS_WIDTH);

    ultra_buffer_memory #(
        .ADDRESS_WIDTH(ADDRESS_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) inner_mem(
        .clock(clock),
        .reset(reset),
        .write_enable(write_enabled && registerd_write),
        .write_address(write_address),
        .read_address(read_address),
        .write_data(write_data),
        .read_data(read_data)
    );
    

    enum reg [2:0] {
        pre_trigger = 1,
        acquisition = 2,
        wait_read_latency = 3,
        output_phase = 4
    } state = pre_trigger;

    
    reg [ADDRESS_WIDTH-1:0] fill_progress_ctr = 0;
    reg [ADDRESS_WIDTH-1:0] read_progress_ctr = 0;
    
    always_ff @( posedge clock ) begin 
        registerd_write <= in.valid;
        if(in.valid & write_enabled & enable)begin
            write_address <= write_address + 1;
            write_data <= in.data;
            if(state == acquisition)begin
                fill_progress_ctr <= fill_progress_ctr +1;
            end else begin
                fill_progress_ctr <= write_address - (write_address-trigger_point);
            end
        end
    end
    
    always_ff @( posedge clock ) begin 
        if(enable)begin
            case (state)
                pre_trigger:begin
                    out.valid <= 0;
                    out.data <= 0;
                    full <= 0;
                    write_enabled <= 1;
                    in.ready <= 1;
                    if(trigger)begin
                        read_address <= write_address-trigger_point +1;
                        state <= acquisition;
                    end
                end
                acquisition:begin
                    if(fill_progress_ctr == MEMORY_DEPTH-1)begin
                        state <= wait_read_latency;
                        in.ready <= 0;
                        read_progress_ctr <= 0;
                        full <= 1;
                    end
                end
                wait_read_latency:begin
                    full <= 0;
                    write_enabled <= 0;
                    read_address <= read_address +1;
                    state <= output_phase;
                end
                output_phase:begin
                    if(out.ready)begin
                        out.valid <= 1;
                        out.data <= read_data;
                        if(read_progress_ctr == MEMORY_DEPTH-1) begin
                            read_address <= 0;
                            state <= pre_trigger;
                        end else begin
                            read_progress_ctr <= read_progress_ctr +1;
                            read_address <= read_address +1;
                        end
                    end else begin
                        out.valid <= 0;
                    end
                end
            endcase
        end
    end



endmodule