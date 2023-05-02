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
    MAX_N_TAPS=8,
    parameter [DATA_PATH_WIDTH-1:0] TAPS_IV [MAX_N_TAPS:0] = '{MAX_N_TAPS+1{0}}
)(
    input wire clock,
    input wire reset,
    input wire [15:0] n_taps,
    input wire [DATA_PATH_WIDTH-1:0] tap_data,
    input wire [15:0] tap_addr,
    input wire tap_write,
    axi_stream.slave data_in,
    axi_stream.master data_out
);
    
    reg [DATA_PATH_WIDTH-1:0] current_tap;
    reg [15:0] tap_counter = 0;

    DP_RAM #(
        .DATA_WIDTH(DATA_PATH_WIDTH),
        .ADDR_WIDTH($clog2(MAX_N_TAPS))
    ) tap_memory(
        .clk(clock),
        .addr_a(tap_addr),
        .data_a(tap_data),
        .addr_b(tap_counter),
        .data_b(current_tap),
        .we_a(tap_write),
        .en_b(1)
    );


    enum logic [2:0] {
        filter_idle = 0,
        filter_running = 1
    } filter_state = filter_idle;


    reg [DATA_PATH_WIDTH-1:0] true_delay_line [101:0] = '{102{0}};

    wire[DATA_PATH_WIDTH-1:0] tdl_out;
    assign tdl_out = true_delay_line[tap_counter-1];
    
    always_ff@(posedge clock) begin
        if(data_in.valid) begin
            true_delay_line[0]<= data_in.data;
            for(int i = 0; i<100; i++)begin
                true_delay_line[i+1] <= true_delay_line[i];
            end
        end
    end

    reg[2*DATA_PATH_WIDTH-1:0] filter_accumulator;

    always_ff@(posedge clock) begin
        case (filter_state)
            filter_idle:begin
                data_out.valid <= 0;
                filter_accumulator <= 0;
                if(data_in.valid)begin
                    data_in.ready <= 0;
                    filter_state <= filter_running;
                    tap_counter <= 1;
                end
            end 
            filter_running:begin
                filter_accumulator <= $signed(filter_accumulator) + $signed(current_tap)*$signed(tdl_out);
                if(tap_counter==n_taps)begin
                    data_in.ready <= 1;
                    data_out.data <= filter_accumulator>>>15;
                    data_out.valid <= 1;
                    filter_state <= filter_idle;
                end else begin
                    tap_counter <= tap_counter+1;
                end
            end
        endcase
    end



endmodule