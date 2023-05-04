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
`include "interfaces.svh"

module fir_filter_serial #(
    parameter DATA_PATH_WIDTH = 16,
    TAP_WIDTH = 16,
    WORKING_WIDTH = DATA_PATH_WIDTH > TAP_WIDTH ? DATA_PATH_WIDTH : TAP_WIDTH,
    MAX_N_TAPS=8,
    parameter [WORKING_WIDTH-1:0] TAPS_IV [MAX_N_TAPS:0] = '{MAX_N_TAPS+1{0}}
)(
    input wire clock,
    input wire reset,
    input wire [$clog2(MAX_N_TAPS)-1:0] n_taps,
    input wire [WORKING_WIDTH-1:0] tap_data,
    input wire [$clog2(MAX_N_TAPS)-1:0] tap_addr,
    input wire tap_write,
    axi_stream.slave data_in,
    axi_stream.master data_out
);
    
    reg [WORKING_WIDTH-1:0] current_tap;
    reg [15:0] tap_counter = 0;
    wire [WORKING_WIDTH-1:0] scaled_tap_data;
    wire [WORKING_WIDTH-1:0] scaled_data_in;

    generate
        if(DATA_PATH_WIDTH>TAP_WIDTH)begin
            assign scaled_tap_data = tap_data<<(DATA_PATH_WIDTH-TAP_WIDTH);
        end else begin
            assign scaled_tap_data = tap_data;
        end

        if(TAP_WIDTH>DATA_PATH_WIDTH)begin
            assign scaled_data_in = data_in.data<<(TAP_WIDTH-DATA_PATH_WIDTH);
        end else begin
            assign scaled_data_in = data_in.data;
        end
    endgenerate


    DP_RAM #(
        .DATA_WIDTH(WORKING_WIDTH),
        .ADDR_WIDTH($clog2(MAX_N_TAPS)),
        .INIT_LEN(MAX_N_TAPS+1),
        .MEM_INIT(TAPS_IV)
    ) tap_memory(
        .clk(clock),
        .addr_a(tap_addr),
        .data_a(scaled_tap_data),
        .addr_b(tap_counter),
        .data_b(current_tap),
        .we_a(tap_write),
        .en_b(1)
    );


    enum logic [2:0] {
        filter_idle = 0,
        filter_running = 1
    } filter_state = filter_idle;


    reg [$clog2(MAX_N_TAPS)-1:0] dl_write_addr = 0;
    reg [$clog2(MAX_N_TAPS)-1:0] dl_read_addr;
    wire [WORKING_WIDTH-1:0] dl_out;
    
    always_ff@(posedge clock) begin
        if(data_in.valid)begin
            if(dl_write_addr == n_taps) begin
                dl_write_addr <= 0;
            end else begin
                dl_write_addr <= dl_write_addr + 1;
            end
            dl_read_addr <= dl_write_addr;
        end


        if(filter_state == filter_running)begin
            if(dl_read_addr == 0) begin
                dl_read_addr <= n_taps;
            end else begin
                dl_read_addr <= dl_read_addr - 1;
            end
        end
    end
    
    

    DP_RAM #(
        .DATA_WIDTH(WORKING_WIDTH),
        .ADDR_WIDTH($clog2(MAX_N_TAPS))
    ) dl(
        .clk(clock),
        .addr_a(dl_write_addr),
        .data_a(scaled_data_in),
        .addr_b(dl_read_addr),
        .data_b(dl_out),
        .we_a(data_in.valid),
        .en_b(1)
    );



    reg[2*WORKING_WIDTH-1:0] filter_accumulator;
    reg [15:0] latched_dest;
    always_ff@(posedge clock) begin
        case (filter_state)
            filter_idle:begin
                data_in.ready <= 1;
                data_out.valid <= 0;
                filter_accumulator <= 0;
                if(data_in.valid)begin
                    data_in.ready <= 0;
                    latched_dest <= data_in.dest;
                    filter_state <= filter_running;
                    tap_counter <= 0;
                end
            end 
            filter_running:begin
                filter_accumulator <= $signed(filter_accumulator) + $signed(current_tap)*$signed(dl_out);
                if(tap_counter==n_taps)begin
                    data_in.ready <= 1;
                    if(DATA_PATH_WIDTH>=TAP_WIDTH)
                        data_out.data <= filter_accumulator>>>(WORKING_WIDTH-1);
                    else    
                        data_out.data <= filter_accumulator>>>(WORKING_WIDTH-1+TAP_WIDTH-DATA_PATH_WIDTH);
                    data_out.dest <= latched_dest;
                    data_out.valid <= 1;
                    filter_state <= filter_idle;
                end else begin
                    tap_counter <= tap_counter+1;
                end
            end
        endcase
    end



endmodule