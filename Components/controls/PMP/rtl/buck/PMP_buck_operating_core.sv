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

module PMP_buck_operating_core #(
    PWM_BASE_ADDR = 0,
    N_PWM_CHANNELS = 2,
    N_PHASES = 4
)(
    input wire clock,
    input wire reset,
    input wire start,
    input wire stop,
    input wire pwm_config_done,
    input wire [3:0] update,
    input wire [15:0] period,
    input wire [15:0] duty[N_PHASES-1:0],
    input wire [15:0] phase_shifts[N_PHASES-1:0],
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
    localparam duty_register_offset = N_PWM_CHANNELS;



    ////////////////////////////////////////////
    //         OPERATING CONFIG FSM           //
    ////////////////////////////////////////////



    reg [$clog2(N_PHASES)-1:0] operating_chain_counter = 0;

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

    reg start_needed = 1;

    reg latched_stop_request;

    always @(posedge clock) begin : operating_fsm
        if (~reset) begin
            modulator_status <= 0;
            latched_stop_request <= 0;
        end else begin
            if(stop)
                latched_stop_request <= 1;

        
            case (opeating_state)
                operating_idle: begin

                    if(update && modulator_status == 1)begin
                        opeating_state <= update_phase_shift;
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
                    if(operating_write.ready)begin
                        operating_write.data <= period;
                        operating_write.dest <= PWM_BASE_ADDR + period_register_offset + (operating_chain_counter+1)*'h100;
                        operating_write.valid <= 1;
                        if(operating_chain_counter == N_PHASES-1) begin
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
                        operating_write.data <= phase_shifts[operating_chain_counter];
                        operating_write.dest <= PWM_BASE_ADDR + phase_shift_register_offset + (operating_chain_counter+1)*'h100;
                        operating_write.valid <= 1;
                        if(operating_chain_counter == N_PHASES-1) begin
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
                        operating_write.dest <= PWM_BASE_ADDR+ duty_register_offset + (operating_chain_counter+1)*'h100;
                        operating_write.data <= duty[operating_chain_counter];
                        
                        operating_write.valid <= 1;

                        if(operating_chain_counter == N_PHASES-1) begin
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
                
                    end
                end
                wait_write_end:begin
                    if(operating_write.ready)begin
                        operating_write.valid <= 0;
                        opeating_state <= next_state;
                    end  
                end
            endcase

        end
    end
    
endmodule
