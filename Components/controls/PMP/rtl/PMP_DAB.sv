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
    N_PWM_CHANNELS = 4
)(
    input wire clock,
    input wire reset,
    input wire configure,
    input wire start,
    input wire stop,
    input wire [3:0] update,
    input wire [1:0] modulation_type,
    input wire [15:0] period,
    input wire [15:0] duty_1,
    input wire [15:0] duty_2,
    input wire signed [15:0] phase_shift_1,
    input wire signed [15:0] phase_shift_2,
    output reg modulator_status,
    output reg done,
    axi_stream.master write_request
);

    localparam  modulator_off = 0;
    localparam  modulator_on = 1;

    localparam pwm_ctrl_addr = 0;
    localparam pwm_chain_1_base = 4;


    reg [31:0] config_data [2:0] = '{'hff, 'h1, 'h1100};
    reg [31:0] config_addr [2:0] = '{
        'h100+(3*N_PWM_CHANNELS+3)*4, 
        'h100+(3*N_PWM_CHANNELS+5)*4,
        'h0};

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


    reg [31:0] modulator_on_config_register = 'h1128;
    reg [31:0] modulator_timebase_shift_addr = 'h12c;
    
    reg update_needed = 0;
    reg sps_start, dps_start, sps_done, dps_done;
    reg [3:0] config_counter;
    
    typedef enum reg [3:0] {
        calc_idle_state = 0,
        configuration_state = 1,
        write_strobe = 2,
        update_modulator = 3
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
            sps_start <= 0;
            sps_done <= 0;
            dps_start <= 0;
            dps_done <= 0;
            modulator_status <= modulator_off;
        end else begin
            modulator_registers_data[0] <=period;

            case (calculation_state)
                calc_idle_state: begin
                    update_needed <= update_needed | (|update);
                    done <= 0;
                    write_request.valid <= 0;
                    
                    if(configure)begin
                        config_counter <= 0;
                        calculation_state <= configuration_state;
                    end

                    if(update_needed & modulator_status==modulator_off)begin
                        if(modulation_type == 0)begin
                            sps_start <= 1;
                        end else if(modulation_type == 1)begin
                            dps_start <= 1;
                        end
                        update_needed <=0;
                    end

                    if(sps_done | dps_done)begin
                        sps_done <= 0;
                        dps_done <= 0;
                        config_counter <= 0;
                        calculation_state <= update_modulator;
                    end

                     if(start) begin 
                        modulator_status <= modulator_on;
                        write_request.dest <= PWM_BASE_ADDR;
                        write_request.data <= modulator_on_config_register;
                        write_request.valid <= 1;
                    end

                    if(stop) begin 
                        modulator_status <= modulator_off;
                        write_request.dest <= PWM_BASE_ADDR;
                        write_request.data <= config_data[0];
                        write_request.valid <= 1;
                    end
                end
                configuration_state:begin
                    update_needed <= update_needed | (|update);
                    if(write_request.ready)begin
                        write_request.dest <= PWM_BASE_ADDR + config_addr[config_counter];
                        write_request.data <= config_data[config_counter];
                        write_request.valid <= 1;
                        if(config_counter==2)begin
                            calculation_state <= calc_idle_state;
                            done <= 1;
                        end else begin
                            next_state <= configuration_state;
                            calculation_state <= write_strobe;
                        end    
                    end
                end
                write_strobe:begin
                    update_needed <= update_needed | (|update);
                    write_request.valid <= 0;
                    if(~write_request.ready)begin   
                        config_counter <= config_counter+1;
                        calculation_state <= next_state;    
                    end
                end

                update_modulator:begin
                    if(write_request.ready)begin
                        write_request.dest <= PWM_BASE_ADDR + modulator_registers_address[config_counter];
                        write_request.data <= modulator_registers_data[config_counter];
                        write_request.valid <= 1;
                        if(config_counter==8)begin
                            calculation_state <= calc_idle_state;
                        end else begin
                            next_state <= update_modulator;
                            calculation_state <= write_strobe;
                        end    
                    end
                end
            endcase

            if(sps_start)begin
                sps_start <= 0;

                modulator_registers_data[1] <= period/2 - duty_1/2;
                modulator_registers_data[2] <= period/2 - duty_1/2;
                modulator_registers_data[5] <= period/2 + duty_1/2;
                modulator_registers_data[6] <= period/2 + duty_1/2;

                modulator_registers_data[3] <= s_period/2 - s_duty_1/2 + phase_shift_1/2;
                modulator_registers_data[4] <= s_period/2 - s_duty_1/2 + phase_shift_1/2;

                modulator_registers_data[7] <= s_period/2 + s_duty_1/2 + phase_shift_1/2;
                modulator_registers_data[8] <= s_period/2 + s_duty_1/2 + phase_shift_1/2;
                sps_done <= 1;
            end

            if(dps_start)begin
                dps_start <= 0;
                
                modulator_registers_data[1] <= period/2 - duty_1/2;
                modulator_registers_data[5] <= period/2 + duty_1/2;
                modulator_registers_data[2] <= s_period/2 - s_duty_1/2 + phase_shift_2/2;
                modulator_registers_data[6] <= s_period/2 + s_duty_1/2 + phase_shift_2/2;

                modulator_registers_data[3] <= s_period/2 - s_duty_1/2 + phase_shift_1/2;
                modulator_registers_data[7] <= s_period/2 + s_duty_1/2 + phase_shift_1/2;
                modulator_registers_data[4] <= s_period/2 - s_duty_1/2 + phase_shift_1/2+phase_shift_2/2;
                modulator_registers_data[8] <= s_period/2 + s_duty_1/2 + phase_shift_1/2+phase_shift_2/2;
                
                sps_done <= 1;
            end
        end
    end
    
endmodule
