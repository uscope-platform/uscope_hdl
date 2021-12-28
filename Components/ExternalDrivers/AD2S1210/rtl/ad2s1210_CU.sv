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

module ad2s1210_cu #(parameter BASE_ADDRESS = 32'h43c00000)(
    input wire clock,
    input wire reset,
    input wire read_angle,
    input wire read_speed,
    input wire SPI_ready,
    output wire SPI_valid,
    output wire [31:0] SPI_data_out,
    input wire [31:0] SPI_data_in,
    output reg [1:0] mode,
    output reg [1:0] resolution,
    output wire sample,
    output reg rdc_reset,
    output reg [4:0] spi_transfer_length,
    axi_stream.master data_out,
    axi_lite.slave axi_in
);

    reg fc_mode;

    reg read_sample, fault_clear_sample;

 
    reg [1:0] internal_mode;

    reg [7:0] AD2S1210_addr[0:14] = '{'h80,'h81,'h82,'h83,'h88,'h89,'h8A,'h8B,'h8C,'h8D,'h8E,'h91,'h92,'hf0,'hff};
    reg [7:0] AD2S1210_values[0:14] = '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};

    reg [7:0] sample_read_delay;
    reg [7:0] sample_pulse_length;

    wire configuration_done, start_configuration;
    assign start_configuration = trigger_out & ~trigger_type;

    wire start_fault_clear, fault_clear_done;
    assign start_fault_clear = trigger_out & trigger_type;
    

    assign mode = state==configure_state | fc_mode ? 2'b11 : internal_mode;
    assign sample = read_sample & fault_clear_sample;



    enum logic [1:0] {
        run_state =             2'b00,
        configure_state =      2'b01,
        fault_clear_state =      2'b11
    } state = run_state;



    always_ff @(posedge clock) begin
        case (state)
            run_state: begin
                if(start_configuration)
                    state <= configure_state;
                else if(start_fault_clear)
                    state <= fault_clear_state;
            end
            configure_state:begin
                if(configuration_done)
                    state <= run_state;
            end
            fault_clear_state:begin
                if(fault_clear_done)
                    state <= run_state;
            end
            default: 
                state <= run_state;
        endcase
    end



    reg clear_fault;
    reg trigger_out;
    reg trigger_type;

    reg [7:0] slow_fault_threshold;

    reg [31:0] cu_write_registers [10:0];
    reg [31:0] cu_read_registers [10:0];

    axil_simple_register_cu #(
        .N_READ_REGISTERS(11),
        .N_WRITE_REGISTERS(11),
        .REGISTERS_WIDTH(32),
        .N_TRIGGER_REGISTERS(1),
        .TRIGGER_REGISTERS_IDX('{9}),
        .INITIAL_OUTPUT_VALUES({32'b0,32'b0,32'b0,32'b0,32'b0,32'b0,32'b0,32'b0,32'b0,32'b0,{3'b0,5'd22,20'b0,2'b10,2'b0}}),
        .BASE_ADDRESS(BASE_ADDRESS)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .trigger_out(trigger_out),
        .axil(axi_in)
    );

    always_comb begin 
        AD2S1210_values[4] <= cu_write_registers[0][31:0];
        AD2S1210_values[5] <= cu_write_registers[1][31:0];
        AD2S1210_values[6] <= cu_write_registers[2][31:0];
        AD2S1210_values[7] <= cu_write_registers[3][31:0];
        AD2S1210_values[8] <= cu_write_registers[4][31:0];
        AD2S1210_values[9] <= cu_write_registers[5][31:0];
        AD2S1210_values[10] <= cu_write_registers[6][31:0];
        AD2S1210_values[11] <= cu_write_registers[7][31:0];
        AD2S1210_values[12] <= cu_write_registers[8][31:0];
        
        trigger_type <= cu_write_registers[9][31:0];

        resolution <= cu_write_registers[10][3:2];
        rdc_reset <= cu_write_registers[10][4];
        sample_pulse_length <= cu_write_registers[10][15:8];
        sample_read_delay <= cu_write_registers[10][23:16];
        spi_transfer_length <= cu_write_registers[10][28:24];
        
        cu_read_registers[0] <= AD2S1210_values[4];
        cu_read_registers[1] <= AD2S1210_values[5];
        cu_read_registers[2] <= AD2S1210_values[6];
        cu_read_registers[3] <= AD2S1210_values[7];
        cu_read_registers[4] <= AD2S1210_values[8];
        cu_read_registers[5] <= AD2S1210_values[9];
        cu_read_registers[6] <= AD2S1210_values[10];
        cu_read_registers[7] <= AD2S1210_values[11];
        cu_read_registers[8] <= AD2S1210_values[12];
        cu_read_registers[9] <= 0;
        cu_read_registers[10] <= {
            3'b0,
            spi_transfer_length,
            sample_read_delay,
            sample_pulse_length,
            3'b0,
            rdc_reset,
            resolution,
            2'b0
        };
    end





    axi_stream read_spi();
    axi_stream cfg_spi();
    axi_stream fc_spi();
    axi_stream spi_control();


    assign SPI_data_out = spi_control.data;
    assign SPI_valid = spi_control.valid;
    assign spi_control.ready = SPI_ready;

    axi_stream_combiner_3 #(
        .INPUT_DATA_WIDTH(32),
        .OUTPUT_DATA_WIDTH(32),
        .MSB_DEST_SUPPORT("FALSE")
    ) spi_stream_combiner (
        .clock(clock),
        .reset(reset),
        .stream_in_1(read_spi),
        .stream_in_2(cfg_spi),
        .stream_in_3(fc_spi),
        .stream_out(spi_control)
    );



    ad2s1210_reader reader (
        .clock(clock),
        .reset(reset),
        .start(read_angle | read_speed),
        .transfer_type(read_speed),
        .sample_length(sample_pulse_length),
        .sample_delay(sample_read_delay),
        .spi_data_in(SPI_data_in),
        .spi_transfer(read_spi),
        .sample(read_sample),
        .mode(internal_mode),
        .data_out(data_out)
    );


    ad2s1210_configurator configurator (
        .clock(clock),
        .reset(reset),
        .start(start_configuration),
        .config_address(AD2S1210_addr),
        .config_data(AD2S1210_values),
        .spi_transfer(cfg_spi),
        .done(configuration_done)
    );


    ad2s1210_fault_handler fault_handler (
        .clock(clock),
        .reset(reset),
        .start(start_fault_clear),
        .sample_delay(sample_read_delay),
        .sample_length(sample_pulse_length),
        .spi_transfer(fc_spi),
        .mode(fc_mode),
        .sample(fault_clear_sample), 
        .done(fault_clear_done)
    );




endmodule