// Copyright 2021 University of Nottingham Ningbo China
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

module SpiControlUnit #(parameter BASE_ADDRESS = 32'h43c0000, SS_POLARITY_DEFAULT = 0, N_CHANNELS=3,  OUTPUT_WIDTH=32) (
    input logic clock,
    input logic reset,
    input logic [OUTPUT_WIDTH-1:0] spi_data_in[N_CHANNELS-1:0],
    input logic transfer_done,
    output logic [3:0] spi_transfer_length,
    output logic [31:0] spi_delay,
    output logic [31:0] spi_data_out [N_CHANNELS-1:0],
    output logic [2:0] divider_setting,
    output logic spi_mode,
    output logic spi_start_transfer,
    output logic spi_direction,
    output logic [31:0] period,
    output logic start_generator_enable,
    output logic ss_polarity,
    output logic clock_polarity,
    output logic ss_deassert_delay_enable,
    output logic latching_edge,
    output logic transfer_length_choice,
    // SIMPLEBUS
    axi_lite.slave axi_in,
    // AXI STREAM WRITE
    input wire SPI_write_valid,
    input wire [31:0] SPI_write_data,
    output reg SPI_write_ready
);

    localparam  N_REGISTERS = 4 + N_CHANNELS;

    localparam [31:0] TRIGGER_REGISTERS_IDX [0:0] = '{3};

    localparam [31:0] INITIAL_OUTPUT_VALUES [3:0]= '{
        0,
        0,
        1,
        {SS_POLARITY_DEFAULT,3'b0,SS_POLARITY_DEFAULT,5'b0,4'hE,4'b0}
    };

    localparam [31:0] VARIABLE_INITIAL_VALUES [N_CHANNELS-1:0] = '{N_CHANNELS{1'b0}};
    
    assign spi_start_transfer = bus_start_transfer | axis_start_transfer;

    reg [31:0] cu_write_registers [N_REGISTERS-1:0];
    reg [31:0] cu_read_registers [N_REGISTERS-1:0];
    reg trigger_transfer;

    reg bus_start_transfer, axis_start_transfer;

    
    reg [31:0] axis_spi_data;
    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_REGISTERS),
        .N_WRITE_REGISTERS(N_REGISTERS),
        .REGISTERS_WIDTH(32),
        .N_TRIGGER_REGISTERS(1),
        .INITIAL_OUTPUT_VALUES({INITIAL_OUTPUT_VALUES, VARIABLE_INITIAL_VALUES}),
        .TRIGGER_REGISTERS_IDX(TRIGGER_REGISTERS_IDX),
        .BASE_ADDRESS(BASE_ADDRESS)
    ) axi_if(
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .trigger_out(trigger_transfer),
        .axil(axi_in)
        );

    always_comb begin 

        spi_mode <= cu_write_registers[0][0];
        divider_setting <= cu_write_registers[0][3:1];
        spi_transfer_length <= cu_write_registers[0][7:4];
        spi_direction <= cu_write_registers[0][9];
        start_generator_enable <= cu_write_registers[0][12];
        ss_polarity <= cu_write_registers[0][13];
        ss_deassert_delay_enable <= cu_write_registers[0][14];
        transfer_length_choice <= cu_write_registers[0][15];
        latching_edge <= cu_write_registers[0][16];
        clock_polarity <= cu_write_registers[0][17];

        spi_delay <= cu_write_registers[1];
        period <= cu_write_registers[2];
        // a write to cu_write_registers[3] is used to trigger a spi transfer

        if(axis_start_transfer)begin
            spi_data_out[0] <= axis_spi_data;
        end else begin
            for(int i = 0; i <N_CHANNELS; i = i+1)begin
                spi_data_out[i] <= cu_write_registers[i+4];    
            end
        end


        cu_read_registers[0][0] <= spi_mode;
        cu_read_registers[0][3:1] <= divider_setting;
        cu_read_registers[0][7:4] <= spi_transfer_length;
        cu_read_registers[0][8] <= 0;
        cu_read_registers[0][9] <= spi_direction;
        cu_read_registers[0][11:10] <= 0;
        cu_read_registers[0][12] <= start_generator_enable;
        cu_read_registers[0][13] <= ss_polarity;
        cu_read_registers[0][14] <= ss_deassert_delay_enable;
        cu_read_registers[0][15] <= transfer_length_choice;
        cu_read_registers[0][16] <= latching_edge;
        cu_read_registers[0][17] <= clock_polarity;
        cu_read_registers[0][31:18] <= 0;

        cu_read_registers[1] <= spi_delay;
        cu_read_registers[2] <= period;
        cu_read_registers[3] <= unit_busy;
        for(int i = 0; i <N_CHANNELS; i = i+1)begin
            cu_read_registers[i+4] <= spi_data_in[i];
        end
        bus_start_transfer <= trigger_transfer;
    end

    reg unit_busy = 0;

    
    always_ff @(posedge clock) begin
        if(!reset)begin
            unit_busy <= 0;
            SPI_write_ready <= 1;
        end else begin
            axis_start_transfer <= 0;
            if(SPI_write_valid) begin
                axis_spi_data  <= SPI_write_data[31:0];
                axis_start_transfer <=1;
                unit_busy <= 1;
                SPI_write_ready <= 0;
            end

            if(spi_start_transfer) begin
                unit_busy <= 1;
                SPI_write_ready <= 0;
            end else if(transfer_done) begin
                unit_busy <= 0;
                SPI_write_ready <= 1;
            end
        end
        
    end


endmodule