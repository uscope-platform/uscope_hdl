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

module PMP_DAB_management_core #(
    PWM_BASE_ADDR = 0,
    N_PWM_CHANNELS = 2
)(
    input wire clock,
    input wire reset,
    input wire configure,
    input wire start,
    input wire stop,
    input wire [15:0] deadtime,
    output reg done,
    output reg pwm_config_done,
    axi_stream.master write_request
);

    ////////////////////////////////////////////
    //           PWM GENERATOR CONFIG         //
    ////////////////////////////////////////////

    localparam n_chains = 2;

    wire [31:0] global_config_data [2:0] = '{'hff, 'hf, 'h1};
    wire [31:0] global_config_addr [2:0] = '{
        (3*N_PWM_CHANNELS+3)*4, 
        (3*N_PWM_CHANNELS+4)*4,
        (3*N_PWM_CHANNELS+5)*4
    };

    wire [31:0] dt_config_addr = (2*N_PWM_CHANNELS)*4;


    reg [3:0] management_config_counter = 0;
    reg management_chain_counter = 0;
    
    typedef enum reg [2:0] {
        management_idle = 0,
        fixed_configuration_state = 1,
        wait_fixed_write_end = 2,
        operating_configuration_state = 3,
        wait_operating_write_end = 4

    } management_fsm_state;

    management_fsm_state management_state = management_idle;

    always @ (posedge clock) begin : management_fsm
        if (~reset) begin
            pwm_config_done <= 0;
        end else begin
            case(management_state)
                management_idle: begin
                    done <= 0;
                    
                    if(configure)begin
                        management_config_counter <= 0;
                        management_state <= fixed_configuration_state;
                    end

                    if(start)begin
                        management_state <= operating_configuration_state;
                    end

                    if(stop) begin 
                        pwm_config_done <= 0;
                    end
                end
                fixed_configuration_state:begin
                    if(write_request.ready)begin
                        write_request.dest <= PWM_BASE_ADDR + (management_chain_counter+1)*'h100 + global_config_addr[management_config_counter];
                        write_request.data <= global_config_data[management_config_counter];
                        write_request.valid <= 1;
                       
                        if(management_config_counter==2)begin
                            management_config_counter <= 0;
                            if(management_chain_counter == 1)begin    
                                management_chain_counter <= 0;
                                management_state <= wait_fixed_write_end;
                            end else begin
                                management_chain_counter <= management_chain_counter +1;
                            end
                        end else begin
                            management_config_counter <= management_config_counter+1;
                            management_state <= fixed_configuration_state;
                        end    
                    end
                end
                wait_fixed_write_end:begin
                    if(write_request.ready)begin
                        done <= 1;
                        write_request.valid <= 0;
                        management_state <= management_idle;
                    end      
                end
                operating_configuration_state:begin
                    if(write_request.ready)begin
                        write_request.dest <= PWM_BASE_ADDR + (management_chain_counter+1)*'h100 + dt_config_addr + management_config_counter*4;
                        write_request.data <= deadtime;
                        write_request.valid <= 1;
                        if(management_config_counter==N_PWM_CHANNELS-1)begin
                            management_config_counter <= 0;
                            if(management_chain_counter == 1)begin    
                                management_state <= wait_operating_write_end;
                            end else begin    
                                management_chain_counter <= management_chain_counter +1;
                            end
                        end else begin
                            management_config_counter <= management_config_counter+1;
                            management_state <= operating_configuration_state;
                        end
                    end
                end
                wait_operating_write_end:begin
                    if(write_request.ready)begin
                        pwm_config_done <= 1;
                        write_request.valid <= 0;
                        management_chain_counter <= 0;
                        management_state <= management_idle;
                    end  
                end
            endcase

        end
    end
    
    
endmodule
