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
    Simplebus.slave sb
);
    
    localparam resolver_dest_angle = 0;
    localparam resolver_dest_speed = 1;
    reg read_type;

    reg read_SPI_valid, config_SPI_valid, fc_mode;
    reg [31:0] read_SPI_data, config_SPI_data;

    reg read_sample, fault_clear_sample;

    wire[31:0] int_readdata;
    reg act_state_ended;
    
    //FSM state registers
    reg act_ended=0;
 
    reg [1:0] internal_mode;

    reg [7:0] AD2S1210_addr[0:14] = '{'h80,'h81,'h82,'h83,'h88,'h89,'h8A,'h8B,'h8C,'h8D,'h8E,'h91,'h92,'hf0,'hff};
    reg [7:0] AD2S1210_values[0:14] = '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};

    reg [7:0] sample_read_delay;
    reg [7:0] sample_pulse_length;

    reg [31:0]  latched_adress;
    reg [31:0] latched_writedata;

    reg configuration_done, start_configuration;
    

    reg read_in_progress;

    reg start_fault_clear;
    reg fault_clear_done;
    
    reg [15:0] fc_SPI_data;
    reg fc_SPI_valid;    
    
    enum logic [2:0] {
        idle_state =             3'b000,
        act_state =              3'b001,
        do_configuration_state = 3'b010,
        fault_clear_state =      3'b011
    } state;
    
    
    RegisterFile Registers(
        .clk(clock),
        .reset(reset),
        .addr_a(sb.sb_address-BASE_ADDRESS),
        .data_a(sb.sb_write_data),
        .we_a(sb.sb_write_strobe),
        .q_a(int_readdata)
    );
    
    assign sb.sb_read_data = sb.sb_read_valid ? int_readdata : 0;
     
    assign SPI_data_out = state==do_configuration_state ? config_SPI_data : read_SPI_data | fc_SPI_data;
    assign SPI_valid = state==do_configuration_state ? config_SPI_valid : read_SPI_valid | fc_SPI_valid;
    assign mode = (state==do_configuration_state) | fc_mode ? 2'b11 : internal_mode;
    assign sample = read_sample & fault_clear_sample;
   

    //latch bus writes
    always @(posedge clock) begin
        if(~reset) begin
            latched_adress<=0;
            latched_writedata<=0;
        end else begin
            if(sb.sb_write_strobe & state == idle_state) begin
                latched_adress <= sb.sb_address-BASE_ADDRESS;
                latched_writedata <= sb.sb_write_data;
            end else begin
                latched_adress <= latched_adress;
                latched_writedata <= latched_writedata;
            end
        end
    end


    // Determine the next state
    always @ (posedge clock) begin : control_state_machine
        if (~reset) begin
            state <=idle_state;
            act_state_ended <= 0;
            start_fault_clear <= 0;
            start_configuration <= 0;
            resolution <= 2'b10;
            sb.sb_ready <= 1;
            spi_transfer_length <= 22;
            rdc_reset <= 0;
        end else begin
            sb.sb_read_valid <= 0;
            case (state)
                idle_state: //wait for command
                    if(read_in_progress) begin
                        if(sb.sb_write_strobe) begin
                            sb.sb_ready <=0;
                            state <= act_state;
                            if(sb.sb_address-BASE_ADDRESS == 32'h24 & sb.sb_write_data==0) begin
                                state <= do_configuration_state;
                                start_configuration <= 1;
                            end else if(sb.sb_address-BASE_ADDRESS == 32'h24 & sb.sb_write_data==1) begin
                                state <= fault_clear_state;
                                start_fault_clear <= 1;
                            end
                        end else if(sb.sb_read_strobe) begin
                            sb.sb_read_valid <= 1;
                        end else begin
                            state <=idle_state;
                        end    
                    end
                act_state: // Act on shadowed write
                    if(act_state_ended) begin
                        state <= idle_state;
                        sb.sb_ready <=1;
                    end else begin
                        state <= act_state;
                    end
                do_configuration_state: begin
                    start_configuration <= 0;
                    if(configuration_done)begin
                        state <= idle_state;
                        sb.sb_ready <=1;
                    end else begin
                        state <= do_configuration_state;
                    end
                end
                fault_clear_state: begin
                    start_fault_clear <= 0;
                    if(fault_clear_done)begin
                        state <= idle_state;
                        sb.sb_ready <= 1;
                    end else begin
                        state <= fault_clear_state;
                    end
                end
            endcase
            
            case (state)
                idle_state: begin
                        act_state_ended <= 0;
                    end
                act_state: begin
                    case (latched_adress)
                        32'h00: begin
                            AD2S1210_values[4] <= latched_writedata[7:0];
                        end
                        32'h04: begin
                            AD2S1210_values[5] <= latched_writedata[7:0];
                        end
                        32'h08: begin
                            AD2S1210_values[6] <= latched_writedata[7:0];
                        end
                        32'h0C: begin
                            AD2S1210_values[7] <= latched_writedata[7:0];
                        end
                        32'h10: begin
                            AD2S1210_values[8] <= latched_writedata[7:0];
                        end
                        32'h14: begin
                            AD2S1210_values[9] <= latched_writedata[7:0];
                        end
                        32'h18: begin
                            AD2S1210_values[10] <= latched_writedata[7:0];
                        end
                        32'h1c: begin
                            AD2S1210_values[11] <= latched_writedata[7:0];
                        end
                        32'h20: begin
                            AD2S1210_values[12] <= latched_writedata[7:0];
                        end
                        32'h28: begin
                            resolution <= latched_writedata[3:2];
                            rdc_reset <= latched_writedata[4];
                            sample_pulse_length <= latched_writedata[15:8];
                            sample_read_delay <= latched_writedata[23:16];
                            spi_transfer_length <= latched_writedata[28:24];
                        end
                    endcase
                    act_state_ended<=1;
                    end
            endcase
        end
    end


    axi_stream read_spi();
    assign read_SPI_data = read_spi.data;
    assign read_SPI_valid = read_spi.valid;
    assign read_spi.ready = SPI_ready;

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
        .read_in_progress(read_in_progress),
        .mode(internal_mode),
        .data_out(data_out)
    );
    

    axi_stream cfg_spi();
    assign config_SPI_data = cfg_spi.data;
    assign config_SPI_valid = cfg_spi.valid;
    assign cfg_spi.ready = SPI_ready;

    ad2s1210_configurator configurator (
        .clock(clock),
        .reset(reset),
        .start(start_configuration),
        .config_address(AD2S1210_addr),
        .config_data(AD2S1210_values),
        .spi_transfer(cfg_spi),
        .done(configuration_done)
    );


    axi_stream fc_spi();
    assign fc_SPI_data = fc_spi.data;
    assign fc_SPI_valid = fc_spi.valid;
    assign fc_spi.ready = SPI_ready;

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