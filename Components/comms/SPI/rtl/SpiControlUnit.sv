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
    output logic clockgen_enable,
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
    Simplebus.slave simple_bus,
    // AXI STREAM WRITE
    input wire SPI_write_valid,
    input wire [31:0] SPI_write_data,
    output reg SPI_write_ready
);


    //Latched SimpleBus registers
    logic [31:0] latched_write_data = 0;
    logic [31:0] latched_address = 0;
    logic [31:0] register_readback;

    //SPI settings Registers 
    logic [31:0] spi_start_delay = 0;

    //Data registers
    logic [31:0] read_spi_data = 0;
    
    //FSM registers
    enum logic [2:0] {
        wait_state = 0,
        bus_write_state = 1,
        start_transfer_state=3,
        transfer_in_progress_state=4
    } state = wait_state;

    logic bus_write_done = 0;

    reg read_data_blanking;



    //REGISTER FILE FOR READBACK
    RegisterFile Registers(
        .clk(clock),
        .reset(reset),
        .addr_a(simple_bus.sb_address-BASE_ADDRESS),
        .data_a(simple_bus.sb_write_data),
        .we_a(simple_bus.sb_write_strobe),
        .q_a(register_readback)
    );
    

    always_comb begin
        if(~reset) begin
            simple_bus.sb_read_data <=0;
        end else begin
            if(read_data_blanking) begin
                simple_bus.sb_read_data <= 0;
            end else begin
                if(latched_address==8'h10) simple_bus.sb_read_data <= spi_data_in[0];
                else if(latched_address==8'h20) simple_bus.sb_read_data <= spi_data_in[1];
                else if(latched_address==8'h24) simple_bus.sb_read_data <= spi_data_in[2];
                else simple_bus.sb_read_data <=register_readback;
            end
        end
    end

    always @(posedge clock) begin
        if(~reset) begin
            latched_address<=0;
            latched_write_data<=0;
        end else begin
            if((simple_bus.sb_write_strobe || simple_bus.sb_read_strobe) & state == wait_state) begin
                latched_address <= simple_bus.sb_address-BASE_ADDRESS;
                latched_write_data <= simple_bus.sb_write_data;
            end else begin
                latched_address <= latched_address;
            end
        end
    end

// Determine the next state
    always @ (posedge clock) begin
        if (!reset) begin
            //RESET OUTPUTS
            read_data_blanking <= 1;
            simple_bus.sb_ready <= 1'b1;
            divider_setting <= 0;
            spi_data_out <= '{N_CHANNELS{0}};
            spi_mode <= 0;
            spi_delay <= 1;
            clockgen_enable <= 0;
            transfer_length_choice <= 0;
            ss_deassert_delay_enable <= 0;
            start_generator_enable <= 0;
            spi_start_transfer <= 0;
            spi_direction <= 0;
            period <= 0;
            ss_polarity <= SS_POLARITY_DEFAULT;
            latching_edge <= 0;
            //RESET INTERNAL VARIABLES
            spi_transfer_length <= 14;

            state <= wait_state;
            
        end else begin
            case (state)
                wait_state: begin
                    if(SPI_write_valid)begin
                        state <= start_transfer_state;
                        spi_data_out[0] <= SPI_write_data[31:0];
                        simple_bus.sb_ready <= 0;
                        SPI_write_ready <= 0;
                    end else if(simple_bus.sb_write_strobe)begin
                        simple_bus.sb_ready <= 0;
                        SPI_write_ready <= 0;
                        if(simple_bus.sb_address-BASE_ADDRESS == 8'h0C) begin
                            state <= start_transfer_state;
                        end else begin
                            state<=bus_write_state;
                        end
                    end else if(simple_bus.sb_read_strobe) begin
                        simple_bus.sb_ready <= 0;
                        SPI_write_ready <= 0;
                        read_data_blanking <= 0;
                        state<=wait_state;
                    end else begin
                        read_data_blanking <= 1;
                        simple_bus.sb_ready <= 1;
                        SPI_write_ready <= 1;
                        state<=wait_state;
                    end
                end
                bus_write_state: begin
                    if(bus_write_done) begin
                        simple_bus.sb_ready <=1;
                        SPI_write_ready <= 1;
                        state <= wait_state;
                    end else begin
                        state <= bus_write_state;
                    end
                end
                start_transfer_state: begin
                    state <= transfer_in_progress_state;
                end 
                transfer_in_progress_state: begin
                    if(transfer_done) begin
                        simple_bus.sb_ready <=1;
                        SPI_write_ready <= 1;
                        state <= wait_state;
                    end else begin
                        state <= transfer_in_progress_state;
                    end
                end
                default: begin
                    state <= wait_state;
                end
            endcase

            case (state)
                wait_state: begin 
                    bus_write_done <=0;
                end
                bus_write_state: begin
                    case (latched_address)
                        8'h00: begin
                            spi_mode <= latched_write_data[0];
                            divider_setting <= latched_write_data[3:1];
                            spi_transfer_length <= latched_write_data[7:4];
                            clockgen_enable <= latched_write_data[8];
                            spi_direction <= latched_write_data[9];
                            start_generator_enable <= latched_write_data[12];
                            ss_polarity <= latched_write_data[13];
                            ss_deassert_delay_enable <= latched_write_data[14];
                            transfer_length_choice <= latched_write_data[15];
                            latching_edge <= latched_write_data[16];
                            clock_polarity <= latched_write_data[17];
                            bus_write_done <=1;
                        end
                        8'h04: begin
                            spi_delay <= latched_write_data[31:0];
                            bus_write_done <=1;
                        end
                        8'h08: begin
                            spi_data_out[0] <= latched_write_data[31:0];
                            bus_write_done <=1;
                        end
                        8'h14: begin
                            period <= latched_write_data[31:0];
                            bus_write_done <=1;
                        end
                        8'h18: begin
                            spi_data_out[1] <= latched_write_data[31:0];
                            bus_write_done <=1;
                        end
                        8'h1C: begin
                            spi_data_out[2] <= latched_write_data[31:0];
                            bus_write_done <=1;
                        end
                    endcase
                   
                end
                start_transfer_state: begin
                    spi_start_transfer <=1;
                end
                transfer_in_progress_state: begin
                    spi_start_transfer <=0;
                end

            endcase

        end
    end


endmodule