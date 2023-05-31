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

module PMP_DAB_operating_core #(
    PWM_BASE_ADDR = 0,
    N_PWM_CHANNELS = 2
)(
    input wire clock,
    input wire reset,
    input wire start,
    input wire stop,
    input wire pwm_config_done,
    input wire [3:0] update,
    input wire [1:0] modulation_type,
    input wire [15:0] period,
    input wire [15:0] duty_1,
    input wire [15:0] duty_2,
    input wire signed [15:0] phase_shift_1,
    input wire signed [15:0] phase_shift_2,
    output reg modulator_status,
    axi_stream.master operating_write
);


    ////////////////////////////////////////////
    //           PWM GENERATOR CONFIG         //
    ////////////////////////////////////////////


    reg [31:0] modulator_on_config_register = 'h28;


    reg [15:0] modulator_registers_data [7:0];
    reg [31:0] modulator_registers_address [7:0];

    initial begin
        for(integer i = 3; i>=0; i--)begin
            modulator_registers_address[i] =  4*i;
            modulator_registers_address[i+4] =  4*i;
        end
    end
    
    localparam period_register_offset = (N_PWM_CHANNELS*3+1)*4;
    localparam phase_shift_register_offset = (N_PWM_CHANNELS*3+2)*4;

    wire signed [16:0] s_period;
    wire signed [16:0] s_duty_1;
    wire signed [16:0] s_duty_2;
    wire signed [16:0] s_phase_shift_1;


    assign s_period = $signed(period);
    assign s_duty_1 = $signed(duty_1);
    assign s_duty_2 = $signed(duty_2);
    assign s_phase_shift_1 = $signed(phase_shift_1);


    reg [3:0] operating_config_counter = 0;
    reg operating_chain_counter = 0;

    typedef enum reg [2:0] {
        operating_idle = 0,
        start_modulator_state = 1,
        wait_configuration = 2,
        update_period = 3,
        update_phase_shift = 4,
        update_modulator = 5,
        wait_write_end = 6
    } operating_fsm_state;

    operating_fsm_state opeating_state = operating_idle;
    operating_fsm_state next_state;

    wire [15:0] inner_phase_shift;
    assign inner_phase_shift = modulation_type ? phase_shift_2/2 : 0;

    reg [15:0] phase_shifts_data [1:0] = '{0, 0};
    
    reg start_needed = 1;

    reg latched_stop_request;
    // Determine the next state

    wire signed [15:0] ps_sat_p;
    wire signed [15:0] ps_sat_n;
    
    assign ps_sat_p = s_period/2;
    assign ps_sat_n = -ps_sat_p;

    always @ (posedge clock) begin : operating_fsm
        if (~reset) begin
            modulator_status <= 0;
            latched_stop_request <= 0;
        end else begin
            if(stop)
                latched_stop_request <= 1;

        
            case (opeating_state)
                operating_idle: begin

                    if(update && modulator_status == 1)begin
                        opeating_state <= update_period;
                    end

                    if(start) begin 
                        opeating_state <= wait_configuration;
                        start_needed <= 1;               
                    end

                    if(latched_stop_request) begin 
                        operating_write.dest <= PWM_BASE_ADDR;
                        modulator_status <= 0;
                        operating_write.data <= 0;
                        operating_write.valid <= 1;
                        opeating_state <= wait_write_end;
                        next_state <= operating_idle;
                        latched_stop_request <= 0;
                    end
                end
                wait_configuration:begin
                    if(pwm_config_done)begin
                        opeating_state <= update_period;
                    end
                end
                start_modulator_state: begin
                    if(operating_write.ready)begin
                        operating_write.dest <= PWM_BASE_ADDR;
                        modulator_status <= 1;
                        operating_write.data <= modulator_on_config_register;
                        operating_write.valid <= 1;
                        start_needed <= 0;
                        opeating_state <= wait_write_end;
                        next_state <= operating_idle;
                    end
                    
                end
                update_period: begin
                    if(s_phase_shift_1>ps_sat_p)begin
                        phase_shifts_data[1] = ps_sat_p;
                    end else if(s_phase_shift_1 < ps_sat_n)begin
                        phase_shifts_data[1] = 0;
                    end else begin
                        phase_shifts_data[1] = period/2+s_phase_shift_1;
                    end 
                    if(operating_write.ready)begin
                            operating_write.data <= period;
                            operating_write.dest <= PWM_BASE_ADDR + period_register_offset + (operating_chain_counter+1)*'h100;
                            operating_write.valid <= 1;
                            if(operating_chain_counter == 1) begin
                                opeating_state <= wait_write_end;
                                next_state <= update_phase_shift;
                                operating_chain_counter <= 0;
                            end else begin
                                operating_chain_counter <= operating_chain_counter +1;
                            end
                        end
                end
                update_phase_shift:begin
                    if(operating_write.ready)begin
                        operating_write.data <= phase_shifts_data[operating_chain_counter];
                        operating_write.dest <= PWM_BASE_ADDR + phase_shift_register_offset + (operating_chain_counter+1)*'h100;
                        operating_write.valid <= 1;
                        if(operating_chain_counter == 1) begin
                            opeating_state <= wait_write_end;
                            next_state <= update_modulator;
                            operating_chain_counter <= 0;
                        end else begin
                            operating_chain_counter <= operating_chain_counter +1;
                        end
                    end
                end
                update_modulator: begin
                    if(operating_write.ready)begin
                        if(operating_chain_counter == 1)begin
                            operating_write.dest <= PWM_BASE_ADDR + modulator_registers_address[4+operating_config_counter]+ (operating_chain_counter+1)*'h100;
                            operating_write.data <= modulator_registers_data[4+operating_config_counter];
                        end else begin
                            operating_write.dest <= PWM_BASE_ADDR + modulator_registers_address[operating_config_counter]+ (operating_chain_counter+1)*'h100;
                            operating_write.data <= modulator_registers_data[operating_config_counter];
                        end
                        
                        
                        operating_write.valid <= 1;
                        if(operating_config_counter==3)begin
                            operating_config_counter <= 0;

                            if(operating_chain_counter == 1) begin
                                if(start_needed) begin
                                    next_state <= start_modulator_state;
                                end else begin
                                    next_state <= operating_idle;
                                end
                                opeating_state <= wait_write_end;
                                operating_chain_counter <= 0;
                            end else begin
                                operating_chain_counter <= operating_chain_counter +1;
                            end
                        end else begin
                            operating_config_counter <= operating_config_counter + 1;
                            opeating_state <= update_modulator;
                        end    
                    end
                end
                wait_write_end:begin
                    if(operating_write.ready)begin
                        operating_write.valid <= 0;
                        opeating_state <= next_state;
                    end  
                end
            endcase

            if(opeating_state == update_period)begin
                    modulator_registers_data[0] <= s_period/2 - s_period/4 - inner_phase_shift;
                    modulator_registers_data[1] <= s_period/2 - s_period/4 + inner_phase_shift;

                    modulator_registers_data[2] <= s_period/2 + s_period/4 - inner_phase_shift;
                    modulator_registers_data[3] <= s_period/2 + s_period/4 + inner_phase_shift;

                    modulator_registers_data[4] <= s_period/2 - s_period/4 - inner_phase_shift;
                    modulator_registers_data[5] <= s_period/2 - s_period/4 + inner_phase_shift;

                    modulator_registers_data[6] <= s_period/2 + s_period/4 - inner_phase_shift;
                    modulator_registers_data[7] <= s_period/2 + s_period/4 + inner_phase_shift;
            end
        end
    end
    
endmodule
