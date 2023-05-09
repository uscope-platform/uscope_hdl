// Copyright 2021 Filippo Savi
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

module dab_pre_modulation_processor #(
    PWM_BASE_ADDR = 0,
    N_PWM_CHANNELS = 4,
    N_PARAMETERS = 13
)(
    input wire clock,
    input wire reset,
    input wire configure,
    input wire start,
    input wire stop,
    input wire [3:0] update,
    input wire [1:0] modulation_type,
    input wire [15:0] period,
    input wire [15:0] modulation_parameters[N_PARAMETERS-1:0],
    output reg modulator_status,
    output reg done,
    axi_stream.master write_request
);


    wire [15:0] duty_1;
    assign duty_1 = modulation_parameters[0];
    wire [15:0] duty_2;
    assign duty_2 = modulation_parameters[1];
    wire signed [15:0] phase_shift_1;
    assign phase_shift_1 = modulation_parameters[2];
    wire signed [15:0] phase_shift_2;
    assign phase_shift_2 = modulation_parameters[3];
    wire [15:0] deadtime;
    assign deadtime = modulation_parameters[4];

    localparam  modulator_off = 0;
    localparam  modulator_on = 1;


    wire [31:0] global_config_data [3:0] = '{'hff, 'hf, 'h1, 'h00};
    wire [31:0] global_config_addr [3:0] = '{
        'h100+(3*N_PWM_CHANNELS+3)*4, 
        'h100+(3*N_PWM_CHANNELS+4)*4,
        'h100+(3*N_PWM_CHANNELS+5)*4,
        'h0};

    wire [31:0] dt_config_addr = 'h100+(2*N_PWM_CHANNELS)*4;



    reg [15:0] modulator_registers_data [8:0];
    reg [31:0] modulator_registers_address [8:0];

    initial begin
        modulator_registers_address[0] = 'h100 + (3*N_PWM_CHANNELS+1)*4;
        
        for(integer i = 3; i>=0; i--)begin
            modulator_registers_address[i+1] = 'h100 + 4*i;
        end
        for(integer i = 7; i>3; i--)begin
            modulator_registers_address[i+1] = 'h100 + 4*(i+(N_PWM_CHANNELS-4));
        end
    end


    wire signed [16:0] s_period;
    wire signed [16:0] s_duty_1;
    wire signed [16:0] s_duty_2;

    assign s_period = $signed(period);
    assign s_duty_1 = $signed(duty_1);
    assign s_duty_2 = $signed(duty_2);


    reg [31:0] modulator_on_config_register = 'h28;
    
    reg start_needed = 0;
    reg reset_counter = 0;
    reg [3:0] config_counter;
    
    typedef enum reg [3:0] {
        calc_idle_state = 0,
        global_configuration_state = 1,
        deadtime_configuration_state = 2,
        calculate_modulation = 3,
        start_modulator_state = 4,
        write_strobe = 5,
        update_modulator = 6
    } fsm_state;

    fsm_state calculation_state;
    fsm_state next_state;

    // Determine the next state
    always @ (posedge clock) begin : main_fsm
        if (~reset) begin
            calculation_state <= calc_idle_state;
            config_counter <= 0;
            write_request.dest <= 0;
            write_request.data <= 0;
            write_request.valid <= 0;
            start_needed <= 0;
            modulator_status <= modulator_off;
        end else begin
            modulator_registers_data[0] <=period;

            case (calculation_state)
                calc_idle_state: begin
                    done <= 0;
                    write_request.valid <= 0;
                    
                    if(configure)begin
                        config_counter <= 0;
                        calculation_state <= global_configuration_state;
                    end

                    if(update && modulator_status == modulator_on)begin
                        calculation_state <= calculate_modulation;
                    end

                    if(start) begin 
                        start_needed <= 1;
                        calculation_state <= calculate_modulation;
                    end

                    if(stop) begin 
                        modulator_status <= modulator_off;
                        write_request.dest <= PWM_BASE_ADDR;
                        write_request.data <= global_config_data[0];
                        write_request.valid <= 1;
                    end
                end
                calculate_modulation:begin
                    config_counter <= 0;
                    if(start_needed) begin
                        calculation_state <= deadtime_configuration_state;
                    end else begin
                        calculation_state <= update_modulator;
                    end
                end
                global_configuration_state:begin
                    if(write_request.ready)begin
                        write_request.dest <= PWM_BASE_ADDR + global_config_addr[config_counter];
                        write_request.data <= global_config_data[config_counter];
                        write_request.valid <= 1;
                        if(config_counter==3)begin
                            config_counter <= 0;
                            done <= 1;
                            calculation_state <= calc_idle_state;
                        end else begin
                            next_state <= global_configuration_state;
                            calculation_state <= write_strobe;
                        end    
                    end
                end
                deadtime_configuration_state:begin
                    if(write_request.ready)begin
                        write_request.dest <= PWM_BASE_ADDR + dt_config_addr + config_counter*4;
                        write_request.data <= deadtime;
                        write_request.valid <= 1;
                        if(config_counter==N_PWM_CHANNELS-1)begin
                            reset_counter <= 1;
                            next_state <= update_modulator;
                            calculation_state <= write_strobe;
                        end else begin
                            next_state <= deadtime_configuration_state;
                            calculation_state <= write_strobe;
                        end    
                    end
                end
                update_modulator:begin
                    if(write_request.ready)begin
                        write_request.dest <= PWM_BASE_ADDR + modulator_registers_address[config_counter];
                        write_request.data <= modulator_registers_data[config_counter];
                        write_request.valid <= 1;
                        if(config_counter==8)begin
                            config_counter <= 0;
                            if(start_needed) begin
                                reset_counter <= 1;
                                next_state <= start_modulator_state;
                                calculation_state <= write_strobe;
                            end else
                                calculation_state <= calc_idle_state;
                        end else begin
                            next_state <= update_modulator;
                            calculation_state <= write_strobe;
                        end    
                    end
                end
                start_modulator_state:begin
                    if(write_request.ready)begin
                        write_request.dest <= PWM_BASE_ADDR;
                        modulator_status <= modulator_on;
                        write_request.data <= modulator_on_config_register;
                        write_request.valid <= 1;
                        start_needed <= 0;
                        calculation_state <= calc_idle_state;
                    end
                end
                write_strobe:begin
                    write_request.valid <= 0;
                    if(~write_request.ready)begin   
                        if(reset_counter)begin
                            config_counter <= 0;
                            reset_counter <= 0;
                        end else begin
                            config_counter <= config_counter+1;
                        end
                        
                        calculation_state <= next_state;    
                    end
                end
            endcase

            if(calculation_state == calculate_modulation)begin
                if(modulation_type == 0)begin

                    modulator_registers_data[1] <= s_period/2 - s_duty_1/2 - phase_shift_1/2;
                    modulator_registers_data[2] <= s_period/2 - s_duty_1/2 - phase_shift_1/2;

                    modulator_registers_data[5] <= s_period/2 + s_duty_1/2 - phase_shift_1/2;
                    modulator_registers_data[6] <= s_period/2 + s_duty_1/2 - phase_shift_1/2;

                    modulator_registers_data[3] <= s_period/2 - s_duty_1/2 + phase_shift_1/2;
                    modulator_registers_data[4] <= s_period/2 - s_duty_1/2 + phase_shift_1/2;

                    modulator_registers_data[7] <= s_period/2 + s_duty_1/2 + phase_shift_1/2;
                    modulator_registers_data[8] <= s_period/2 + s_duty_1/2 + phase_shift_1/2;
                    
                end else if(modulation_type==1) begin

                    modulator_registers_data[1] <= s_period/2 - s_duty_1/2 - phase_shift_1/2 - phase_shift_2/2;
                    modulator_registers_data[5] <= s_period/2 + s_duty_1/2 - phase_shift_1/2 - phase_shift_2/2;

                    modulator_registers_data[2] <= s_period/2 - s_duty_1/2 - phase_shift_1/2 + phase_shift_2/2;
                    modulator_registers_data[6] <= s_period/2 + s_duty_1/2 - phase_shift_1/2 + phase_shift_2/2;

                    modulator_registers_data[3] <= s_period/2 - s_duty_1/2 + phase_shift_1/2 - phase_shift_2/2;
                    modulator_registers_data[7] <= s_period/2 + s_duty_1/2 + phase_shift_1/2 - phase_shift_2/2;

                    modulator_registers_data[4] <= s_period/2 - s_duty_1/2 + phase_shift_1/2 + phase_shift_2/2;
                    modulator_registers_data[8] <= s_period/2 + s_duty_1/2 + phase_shift_1/2 + phase_shift_2/2;
                end
            end
        end
    end
    
endmodule
