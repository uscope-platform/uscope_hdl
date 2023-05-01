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

module fir_filter #(
    parameter DATA_PATH_WIDTH = 16,
    MAX_FOLDING_FACTOR = 1,
    PARALLEL_ORDER=8
)(
    input wire clock,
    input wire reset,
    axi_lite.slave cfg_in,
    axi_stream.slave data_in,
    axi_stream.master data_out
);

    axi_stream cu_read_addr();
    axi_stream cu_read_data();
    axi_stream cu_write();

    axil_external_registers_cu #(
        .REGISTERS_WIDTH(32),
        .BASE_ADDRESS(0),
        .READ_DELAY(0)
    )CU (
        .clock(clock),
        .reset(reset),
        .read_address(cu_read_addr),
        .read_data(cu_read_data),
        .write_data(cu_write),
        .axi_in(cfg_in)
    );

    reg [$clog2(MAX_FOLDING_FACTOR):0] folding_factor;
    reg [DATA_PATH_WIDTH-1:0] taps [MAX_FOLDING_FACTOR*PARALLEL_ORDER:0]; 
    

    always_ff@(posedge clock) begin
        cu_read_data.valid <= 0;
        cu_write.ready <= 1;
        if(cu_write.valid)begin
            if(cu_write.dest == 0)begin
                folding_factor <= cu_write.data[15:0];
            end else begin
                taps[cu_write.dest-1] <= cu_write.data;
            end
        end

        if(cu_read_addr.valid)begin
            if(cu_read_addr.data == 0)begin
                cu_read_data.data[15:0] <= folding_factor;
            end else begin
                cu_read_data.data <= taps[cu_read_addr.dest-1];
            end 
            cu_read_data.valid <= 1;
        end
    end
    


    reg [$clog2(MAX_FOLDING_FACTOR)-1:0] folding_counter = 0;


    //FSM STATE CONTROL REGISTERS
    enum logic [2:0]{
        filter_idle = 0,
        filter_working = 1
    } filter_state = filter_idle;


    always_ff@(posedge clock) begin
        case (filter_state)
            filter_idle:begin
                if(data_in.valid)begin
                    filter_state <= filter_working;
                    folding_counter <= folding_factor;
                end
            end
            filter_working:begin
                if(folding_counter == 0) begin
                    filter_state <= filter_idle;
                end else begin
                    folding_counter <= folding_counter - 1;
                end
            end 
        endcase
    end


    fir_filter_parallel #(
        .DATA_PATH_WIDTH(DATA_PATH_WIDTH),
        .MAX_FOLDING_FACTOR(MAX_FOLDING_FACTOR),
        .PARALLEL_ORDER(PARALLEL_ORDER)
    )filter_core(
        .clock(clock),
        .reset(reset),
        .current_taps(taps),
        .data_in(data_in),
        .data_out(data_out)
    );


endmodule