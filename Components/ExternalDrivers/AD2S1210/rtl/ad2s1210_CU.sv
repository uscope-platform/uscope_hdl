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
    reg [3:0] configuration_counter;

    reg start_fault_clear;
    reg fault_clear_done;
    
    reg [15:0] fc_SPI_data;
    reg fc_SPI_valid;

    reg [7:0] reader_counter;
    
    enum logic [2:0] {
        idle_state =             3'b000,
        act_state =              3'b001,
        do_configuration_state = 3'b010,
        do_read_state =          3'b011,
        fault_clear_state =      3'b100
    } state;
    
    enum logic [2:0] {
        sample_pulse_state = 3'b000,
        main_read_state    = 3'b001,
        backoff_state      = 3'b010
    } reader_state;



    
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
                    if(read_angle) begin
                        read_type <= resolver_dest_angle;
                        state <= do_read_state;
                        sb.sb_ready <= 0;
                    end else if(read_speed)begin
                        read_type <= resolver_dest_speed;
                        state <= do_read_state;
                        sb.sb_ready <= 0;
                    end else if(sb.sb_write_strobe) begin
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
                do_read_state: begin
                    if((reader_counter == sample_pulse_length-1) & reader_state == backoff_state)begin
                        state <= idle_state;
                        sb.sb_ready <=1;
                    end else begin
                        state <= do_read_state;
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


     


    always@(posedge clock)begin : read_FSM
        if(!reset)begin
            read_sample <= 1;
            reader_state <= sample_pulse_state;
            reader_counter <= 0;
            read_SPI_valid <= 0;
            read_SPI_data <= 0;
            internal_mode <= 0;
            data_out.data <= 0;
            data_out.valid <= 0;
            data_out.dest <= 0;
            data_out.user <= 0;   
        end else begin
            if(state==do_read_state)begin
                case(reader_state)
                    sample_pulse_state: begin
                        if(reader_counter == sample_pulse_length-1)begin
                            read_sample <= 1;
                            reader_counter <= 0;
                            reader_state <= main_read_state;
                        end else begin
                            read_sample <= 0;
                            if(read_type)begin
                                internal_mode <= 2'b10;
                            end else begin
                                internal_mode <= 2'b00;
                            end
                            reader_counter <= reader_counter+1;
                            reader_state <= sample_pulse_state;
                        end
                    end
                    main_read_state: begin
                        reader_counter <= 0;
                        if(reader_counter ==sample_read_delay)begin
                             if(SPI_ready & ~read_SPI_valid) begin
                                read_SPI_data <= 0;
                                read_SPI_valid <= 1;
                                reader_counter <= 0;
                                reader_state <= backoff_state;
                            end else begin
                                reader_state <=main_read_state;
                            end
                        end else begin
                            reader_counter <= reader_counter+1;
                            reader_state <= main_read_state;
                        end
                    end
                    backoff_state: begin
                        read_SPI_valid <= 0;
                        if(SPI_ready & ~SPI_valid)begin
                            if(reader_counter == 1)begin
                                data_out.data <= {8'b0,SPI_data_in[31:8]};
                                data_out.valid <= 1;
                                data_out.dest <= read_type;
                                data_out.user <= SPI_data_in[7:0];    
                            end else begin
                                data_out.valid <= 0;
                            end

                            if(reader_counter == sample_pulse_length-1)begin
                                reader_counter <= 0;
                                reader_state <= sample_pulse_state;
                            end else begin
                                reader_counter <= reader_counter+1;
                                reader_state <= backoff_state;
                            end
                        end
                    end
                endcase
            end
        end
    end


     
    enum logic [1:0]{
        configurator_idle = 2'b00,
        configurator_send_address = 2'b01,
        configurator_send_data    = 2'b10
    } configurator_state;

    always@(posedge clock)begin : configuration_FSM
        if(!reset)begin
            configurator_state <= configurator_idle;
            configuration_done <= 0;
            configuration_counter <= 4;
            config_SPI_valid <= 0;
            config_SPI_data <= 0;
        end else begin
            case (configurator_state)
                configurator_idle:begin
                    if(start_configuration)begin
                        configurator_state <= configurator_send_address;
                    end else begin
                        configurator_state <= configurator_idle;
                    end
                    configuration_done <= 0;
                end
                configurator_send_address: begin
                    if(configuration_counter==13 & SPI_ready & ~config_SPI_valid)begin
                        configuration_done <= 1;
                        configurator_state <= configurator_idle;
                        configuration_counter <= 4;
                    end else if(configuration_counter==13 & config_SPI_valid) begin
                         config_SPI_valid <= 0;
                    end else begin
                        if(SPI_ready & ~config_SPI_valid) begin
                            config_SPI_data <= AD2S1210_addr[configuration_counter];
                            config_SPI_valid <= 1;
                            configurator_state <=configurator_send_data;
                        end else begin
                            configurator_state <=configurator_send_address;
                            config_SPI_valid <= 0;
                        end
                    end
                end
                configurator_send_data: begin
                    if(SPI_ready & ~config_SPI_valid) begin
                        config_SPI_data <= AD2S1210_values[configuration_counter];
                        config_SPI_valid <= 1;
                        configuration_counter <= configuration_counter+1;
                        configurator_state <= configurator_send_address;
                    end else begin
                        config_SPI_valid <= 0;
                        configurator_state <= configurator_send_data;
                    end
                end
            endcase
        end
    end




    enum logic [2:0] {
        fc_idle_state =                   3'b000,
        fc_first_sample_state =           3'b001,
        fc_start_shift_address_in_state = 3'b010,
        fc_wait_address_in_state =        3'b011,
        fc_start_read_fault_state =       3'b100,
        fc_wait_read_fault_state =        3'b101,
        fc_wait_before_resample =         3'b110,
        fc_second_sample_state =          3'b111 
    } fc_state;

    reg [15:0] fc_counter;
    always@(posedge clock)begin : fc_fsm
        if(!reset)begin
            fc_state <= fc_idle_state;
            fault_clear_sample <= 1;
            fault_clear_done <= 0;
            fc_counter <= 0;
            fc_SPI_data <= 0;
            fc_SPI_valid <= 0;
            fc_mode <= 0;
        end else begin
            case (fc_state)
                fc_idle_state: begin
                    fault_clear_done <= 0;
                    if(start_fault_clear)begin
                        fault_clear_sample <= 0;
                        fc_counter <= 0;
                        fc_state <= fc_first_sample_state;
                    end
                end        
                fc_first_sample_state:begin
                    if(fc_counter == sample_pulse_length-1)begin
                        fault_clear_sample <= 1;
                        fc_SPI_data <= 'hff;
                        fc_counter <= 0;
                        fc_mode <= 1;
                        fc_state <= fc_start_shift_address_in_state;
                    end else begin
                        fc_counter <= fc_counter+1;
                    end
                end
                fc_start_shift_address_in_state: begin
                    if(fc_counter ==sample_read_delay)begin
                        if(~SPI_ready) begin
                            fc_state <= fc_wait_address_in_state;
                            fc_counter <= 0;
                            fc_SPI_valid <= 0;
                        end
                        fc_SPI_valid <= 1;
                    end else begin
                        fc_counter <= fc_counter+1;
                    end
                end
                fc_wait_address_in_state:begin
                    fc_SPI_valid <= 0;
                    if(SPI_ready)begin
                        fc_state<= fc_start_read_fault_state;
                        fc_SPI_data <= 'h0;
                    end
                end
                fc_start_read_fault_state: begin
                    if(fc_counter == 20)begin
                        if(~SPI_ready) begin
                            fc_state <= fc_wait_read_fault_state;
                            fc_counter <= 0;
                            fc_SPI_valid <= 0;
                        end
                        fc_SPI_valid <= 1;

                    end else begin
                        fc_SPI_valid  <=0;
                        fc_counter <= fc_counter+1;
                    end 
                end
                fc_wait_read_fault_state: begin
                    fc_SPI_data <= 0;
                    fc_SPI_valid <= 0;
                    if(SPI_ready & ~fc_SPI_valid) begin
                        fc_counter <= 0;
                        fc_state <= fc_wait_before_resample;
                    end 
                end
                fc_wait_before_resample: begin
                    if(fc_counter ==sample_read_delay)begin
                        fc_state <= fc_second_sample_state;
                        fc_counter <= 0;
                        fc_mode <= 0;
                        fault_clear_sample <= 0;
                    end else begin
                        fc_counter <= fc_counter+1;
                    end
                      
                end
                fc_second_sample_state:begin
                    if(SPI_ready & ~fc_SPI_valid)begin
                        if(fc_counter == sample_pulse_length-1)begin
                            fault_clear_sample <= 1;
                            fault_clear_done <= 1;
                            fc_counter <= 0;
                            fc_state <= fc_idle_state;
                        end else begin
                            fc_counter <= fc_counter+1;
                        end
                    end
                end
            endcase
        end
    end





endmodule