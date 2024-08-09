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
    input wire [ADDRESS_WIDTH-1:0] trigger_point,
    output reg full,
    axi_stream.slave in,
    axi_stream.master out
);

    reg [(DATA_WIDTH+DEST_WIDTH+USER_WIDTH)-1:0] write_data = 0;
    wire [DATA_WIDTH-1:0] read_data;
    wire [DEST_WIDTH-1:0] read_dest;
    wire [USER_WIDTH-1:0] read_user;
    reg [ADDRESS_WIDTH-1:0] write_address = 0;
    reg [ADDRESS_WIDTH-1:0] read_address = 0;
    reg registerd_write = 0;
    reg write_enabled = 0;


    localparam MEMORY_DEPTH = (1<<ADDRESS_WIDTH);

    ultra_buffer_memory #(
        .ADDRESS_WIDTH(ADDRESS_WIDTH)
    ) inner_mem(
        .clock(clock),
        .reset(reset),
        .write_enable(write_enabled && registerd_write),
        .write_address(write_address),
        .read_address(read_address),
        .write_data(write_data),
        .read_data({read_user, read_dest, read_data})
    );
    
        
    enum reg [2:0] {
        pre_trigger = 1,
        acquisition = 2,
        wait_read_latency = 3,
        output_phase = 4,
        wait_backslip = 5
    } state = pre_trigger;

    
    reg [ADDRESS_WIDTH-1:0] fill_progress_ctr = 0;
    reg [ADDRESS_WIDTH-1:0] read_progress_ctr = 0;


    wire [DATA_WIDTH-1:0] selected_data;    
    wire [DEST_WIDTH-1:0] selected_dest;    
    wire [USER_WIDTH-1:0] selected_user;  

    reg [DATA_WIDTH-1:0] backpressure_data;    
    reg [DEST_WIDTH-1:0] backpressure_dest;    
    reg [USER_WIDTH-1:0] backpressure_user;  
    
    reg backpressure_slip;

    always_ff @(posedge clock)begin
        if(~backpressure_slip)begin
            if(~out.ready)begin
                backpressure_slip <= 1;
                backpressure_data <= read_data;
            end
        end else begin
            if(out.ready)begin
                backpressure_slip <= 0;
            end
        end
    end
  

    assign selected_data = backpressure_slip ? backpressure_data : read_data;
    assign selected_dest = backpressure_slip ? backpressure_dest : read_dest;
    assign selected_user = backpressure_slip ? backpressure_user : read_user;


    always_ff @( posedge clock ) begin 
        registerd_write <= in.valid;
        if(in.valid & write_enabled & enable)begin
            write_address <= write_address + 1;
            write_data <= {in.user[USER_WIDTH-1:0], in.dest[DEST_WIDTH-1:0], in.data[DATA_WIDTH-1:0]};;
            if(state == acquisition)begin
                fill_progress_ctr <= fill_progress_ctr +1;
            end else begin
                fill_progress_ctr <= write_address - (write_address-trigger_point);
            end
        end else begin
            if(state == output_phase)begin
                fill_progress_ctr <= 0;
            end
        end
    end

    always_ff @( posedge clock ) begin 
        if(state == acquisition)begin
            read_progress_ctr <= 0;
        end else begin
            if(out.ready && out.valid)begin
                read_progress_ctr <= read_progress_ctr +1;
            end
        end

    end
    
    always_ff @( posedge clock ) begin 
        case (state)
            pre_trigger:begin
                out.valid <= 0;
                out.data <= 0;
                out.dest <= 0;
                out.user <= 0;
                out.tlast <= 0;
                full <= 0;
                if(enable)begin
                    write_enabled <= 1;
                    in.ready <= 1;
                    if(trigger)begin
                        if(in.valid)begin
                            read_address <= write_address-trigger_point +1;
                        end else begin
                            read_address <= write_address-trigger_point;
                        end
                        state <= acquisition;
                    end
                end
            end
            acquisition:begin
                if(fill_progress_ctr == MEMORY_DEPTH-1)begin
                    state <= wait_read_latency;
                    in.ready <= 0;
                    full <= 1;
                end
            end
            wait_read_latency:begin
                write_enabled <= 0;
                read_address <= read_address +1;
                state <= output_phase;
            end
            output_phase:begin
                if(out.ready)begin
                    out.valid <= 1;
                    out.data <= selected_data;
                    out.dest <= selected_dest;
                    out.user <= selected_user;
                    if(read_progress_ctr == MEMORY_DEPTH-2) begin
                        out.tlast <= 1;
                        read_address <= 0;
                        state <= pre_trigger;
                    end else begin
                        read_address <= read_address +1;
                    end
                end else begin
                    state <= wait_backslip;
                    read_address <= read_address -1;
                    out.valid <= 0;
                end
            end
            wait_backslip:begin
                if(out.ready)begin
                    read_address <= read_address +1;
                    state <= output_phase;
                    out.valid <= 1;
                end
            end
        endcase
    end



endmodule