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
    input wire [ADDRESS_WIDTH-1:0] packet_length,
    input wire [11:0] trigger_point,
    output reg full,
    axi_stream.slave in,
    axi_stream.master out
);

    localparam MEMORY_DEPTH = (1<<ADDRESS_WIDTH);


    enum reg [2:0] {
        initial_fill = 0,
        pre_trigger = 1,
        acquisition = 2,
        wait_output = 3,
        readout = 4,
        empty_pipeline = 5,
        refresh_data = 6
    } state = initial_fill;



    reg [ADDRESS_WIDTH-1:0] wr_head_ptr = 0;
    reg [ADDRESS_WIDTH-1:0] rd_head_ptr = 0;

    reg [ADDRESS_WIDTH-1:0] rd_ptr = 0;

    reg [ADDRESS_WIDTH-1:0]  read_address = 0;        // Read  Address
    
    wire [USER_WIDTH-1:0] out_user;
    wire [DEST_WIDTH-1:0] out_dest;
    wire [DATA_WIDTH-1:0] out_data;

    ultra_buffer_memory #(
        .ADDRESS_WIDTH(ADDRESS_WIDTH)
    ) inner_mem(
        .clock(clock),
        .reset(reset),
        .write_enable(in.valid && (state == pre_trigger || state == acquisition)),
        .write_address(wr_head_ptr),
        .read_address(read_address),
        .write_data({in.user[USER_WIDTH-1:0], in.dest[DEST_WIDTH-1:0], in.data[DATA_WIDTH-1:0]}),
        .read_data({out_user, out_dest, out_data})
    );
    

    reg [USER_WIDTH-1:0] backpressure_user;
    reg [DEST_WIDTH-1:0] backpressure_dest;
    reg [DATA_WIDTH-1:0] backpressure_data;    

    reg backpressure_slip = 0;

    always_ff @(posedge clock)begin
        if(backpressure_slip)begin
            if(~out.ready)begin
                backpressure_slip <= 0;
                backpressure_user <= out_user;
                backpressure_dest <= out_dest;
                backpressure_data <= out_data;
            end
        end else begin
            if(out.ready)begin
                backpressure_slip <= 1;
            end
        end
    end

    wire [USER_WIDTH-1:0] selected_user;
    wire [DEST_WIDTH-1:0] selected_dest;
    wire [DATA_WIDTH-1:0] selected_data;    
    assign selected_user = backpressure_slip ? out_user : backpressure_user;
    assign selected_dest = backpressure_slip ? out_dest : backpressure_dest;
    assign selected_data = backpressure_slip ? out_data : backpressure_data;

    initial begin
        out.data <= 0;
        out.user <= 0;
        out.dest <= 0;
    end

    reg initial_fill_done = 0;


    reg [ADDRESS_WIDTH-1:0] initial_address = 0;

    wire[ADDRESS_WIDTH-1:0] unused_buffer_length;
    assign unused_buffer_length= (MEMORY_DEPTH-packet_length);

    wire [ADDRESS_WIDTH-1:0] final_aquisition;
    assign final_aquisition = initial_address-unused_buffer_length-1;

    reg [ADDRESS_WIDTH-1:0] refresh_counter = 0;

    always @(posedge clock) begin
        if(state==initial_fill || state==pre_trigger || state==acquisition  || state==refresh_data)begin
            if(in.valid)begin
                wr_head_ptr<= wr_head_ptr +1;
            end
        end
        case (state)
            initial_fill:begin
                in.ready <= 0;
                if(wr_head_ptr == MEMORY_DEPTH-1) begin
                    state <= pre_trigger;
                    wr_head_ptr <= 0;
                    in.ready <= 1;
                end
            end
            pre_trigger: begin
                full <= 0;
                if(trigger)begin
                    state <= acquisition;
                    initial_address <= wr_head_ptr - trigger_point;
                end
            end 
            acquisition: begin
                if(in.valid)begin
                    if(wr_head_ptr == final_aquisition) begin
                        state <= wait_output;
                        read_address <= initial_address;
                        in.ready <= 0;
                        full <= 1;
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
                if(out.ready)begin
                    if(read_address == final_aquisition)begin
                        state <= empty_pipeline;
                    end
                    out.user <= selected_user;
                    out.data <= selected_data;
                    out.dest <= selected_dest;
                    out.valid <= 1;
                    read_address <= read_address + 1;
                end

            end
            empty_pipeline:begin
                rd_head_ptr <= wr_head_ptr;
                if(out.ready)begin
                    state <= refresh_data;
                    out.valid <= 1;
                    out.tlast <= 1;
                    refresh_counter <= 0;
                    out.user <= selected_user;
                    out.data <= selected_data;
                    out.dest <= selected_dest;
                end
            end
            refresh_data:begin
                out.tlast <= 0;
                out.valid <= 0;
                 in.ready <= 1;
                if(refresh_counter == MEMORY_DEPTH-1) begin
                    state <= pre_trigger;
                end
                if(in.valid)begin
                    refresh_counter <= refresh_counter + 1;
                end
            end
        endcase
    end


endmodule