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

module SpiControlUnit #(
    CLOCK_POLARITY_DEFAULT = 0,
    SS_POLARITY_DEFAULT = 0,
    N_CHANNELS=3,
    OUTPUT_WIDTH=32
) (
    input wire clock,
    input wire reset,
    input wire [OUTPUT_WIDTH-1:0] spi_data_in[N_CHANNELS],
    input wire transfer_done,
    output reg [3:0] spi_transfer_length,
    output reg [31:0] spi_delay,
    output reg [31:0] spi_data_out [N_CHANNELS],
    output reg [2:0] divider_setting,
    output reg spi_mode,
    output reg spi_start_transfer,
    output reg spi_direction,
    output reg [31:0] period,
    output reg start_generator_enable,
    output reg ss_polarity,
    output reg clock_polarity,
    output reg ss_deassert_delay_enable,
    output reg latching_edge,
    output reg transfer_length_choice,
    axi_lite.slave axi_in,
    axi_stream.slave external_spi_transfer
);

    typedef struct packed{
        reg [31:18] padding;
        reg clock_polarity;           //17
        reg latching_edge;            //16
        reg transfer_length_choice;   //15
        reg ss_deassert_delay_enable; //14
        reg ss_polarity;              // 13
        reg start_generator_enable;   // 12
        reg [1:0] reserved_2;         // [10:11]
        reg direction;                // 9
        reg reserved_1;               // 8
        reg [3:0] length;             // [7:4]
        reg [2:0] divider;            // [3:1]
        reg mode;                     // 0
    } spi_control_register;

    typedef struct {
        spi_control_register control;
        reg [31:0] ss_delay;
        reg [31:0] period;
        reg [31:0] trigger;
        reg [31:0] data [N_CHANNELS];
    } spi_registers;

    spi_registers write_registers, read_registers;
    reg trigger_transfer;


    axil_simple_register_cu #(
        .READ_TYPE(spi_registers),
        .WRITE_TYPE(spi_registers),
        .INITIAL_OUTPUT_VALUES('{
            control: '{
                clock_polarity: CLOCK_POLARITY_DEFAULT,
                ss_polarity: SS_POLARITY_DEFAULT,
                length: 4'hE,
                default:0
            }, 
            ss_delay: 1,
            default:0
        }),
        .TRIGGER_MASK('{trigger:1, default:0}),
        .ADDRESS_MASK('hff)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(read_registers),
        .output_registers(write_registers),
        .trigger_out(trigger_transfer),
        .axil(axi_in)
    );

    reg unit_busy = 0;

    always_comb begin 
        read_registers = write_registers;
        read_registers.trigger = unit_busy;
        read_registers.data = spi_data_in;
    end

    reg bus_start_transfer, axis_start_transfer;

    assign spi_start_transfer = bus_start_transfer | axis_start_transfer;

    reg [31:0] axis_spi_data;
  

    assign spi_mode = write_registers.control.mode;
    assign divider_setting = write_registers.control.divider;
    assign spi_transfer_length = write_registers.control.length;
    assign spi_direction = write_registers.control.direction; 
    assign start_generator_enable =  write_registers.control.start_generator_enable;
    assign ss_polarity = write_registers.control.ss_polarity;
    assign ss_deassert_delay_enable = write_registers.control.ss_deassert_delay_enable;
    assign transfer_length_choice = write_registers.control.transfer_length_choice;
    assign latching_edge = write_registers.control.latching_edge;
    assign clock_polarity = write_registers.control.clock_polarity;

    assign spi_delay = write_registers.ss_delay;
    assign period = write_registers.period;

    assign spi_data_out[0] = axis_start_transfer ? axis_spi_data : write_registers.data[0];
    assign spi_data_out[1:N_CHANNELS-1] = write_registers.data[1:N_CHANNELS-1];


    assign bus_start_transfer = trigger_transfer;

    always_ff @(posedge clock) begin
        if(!reset)begin
            unit_busy <= 0;
            external_spi_transfer.ready <= 1;
        end else begin
            axis_start_transfer <= 0;
            if(external_spi_transfer.valid) begin
                axis_spi_data  <= external_spi_transfer.data[31:0];
                axis_start_transfer <=1;
                unit_busy <= 1;
                external_spi_transfer.ready <= 0;
            end

            if(spi_start_transfer) begin
                unit_busy <= 1;
                external_spi_transfer.ready <= 0;
            end else if(transfer_done) begin
                unit_busy <= 0;
                external_spi_transfer.ready <= 1;
            end
        end

    end


endmodule
