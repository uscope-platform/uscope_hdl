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
    N_PWM_CHANNELS = 2,
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

    ////////////////////////////////////////////
    //           PARAMETER DECODING           //
    ////////////////////////////////////////////


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

    localparam fixed_carrier_register_offset = N_PWM_CHANNELS*3+2;
    localparam mobile_carrier_register_offset = 0;
    
    reg [31:0] modulator_on_config_register = 'h28;


    reg [15:0] modulator_registers_data [7:0];
    reg [31:0] modulator_registers_address [7:0];

    initial begin
        for(integer i = 3; i>=0; i--)begin
            modulator_registers_address[i] =  4*i;
            modulator_registers_address[i+4] =  4*i;
        end
    end


    
    reg [3:0] config_counter = 0;
    reg chain_counter = 0;
    reg operating_config_done = 0;
    
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
        end else begin
            case(management_state)
                management_idle: begin
                    done <= 0;
                    
                    if(configure)begin
                        config_counter <= 0;
                        management_state <= fixed_configuration_state;
                    end

                    if(start)begin
                        management_state <= operating_configuration_state;
                    end

                    if(stop) begin 
                        operating_config_done <= 0;
                    end
                end
                fixed_configuration_state:begin
                    if(write_request.ready)begin
                        write_request.dest <= PWM_BASE_ADDR + (chain_counter+1)*'h100 + global_config_addr[config_counter];
                        write_request.data <= global_config_data[config_counter];
                        write_request.valid <= 1;
                       
                        if(config_counter==2)begin
                            config_counter <= 0;
                            if(chain_counter == 1)begin    
                                chain_counter <= 0;
                                management_state <= wait_fixed_write_end;
                            end else begin
                                chain_counter <= chain_counter +1;
                            end
                        end else begin
                            config_counter <= config_counter+1;
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
                        write_request.dest <= PWM_BASE_ADDR + (chain_counter+1)*'h100 + dt_config_addr + config_counter*4;
                        write_request.data <= deadtime;
                        write_request.valid <= 1;
                        if(config_counter==N_PWM_CHANNELS-1)begin
                            config_counter <= 0;
                            if(chain_counter == 1)begin    
                                management_state <= wait_operating_write_end;
                            end else begin    
                                chain_counter <= chain_counter +1;
                            end
                        end else begin
                            config_counter <= config_counter+1;
                            management_state <= operating_configuration_state;
                        end
                    end
                end
                wait_operating_write_end:begin
                    if(write_request.ready)begin
                        operating_config_done <= 1;
                        write_request.valid <= 0;
                        chain_counter <= 0;
                        management_state <= management_idle;
                    end  
                end
            endcase

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

    reg [31:0] modulator_on_config_register = 'h28;
    
    reg start_needed = 1;

    reg latched_stop_request;
    // Determine the next state
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
                        write_request.dest <= PWM_BASE_ADDR;
                        modulator_status <= 0;
                        write_request.data <= 0;
                        write_request.valid <= 1;
                        opeating_state <= wait_write_end;
                        next_state <= operating_idle;
                        latched_stop_request <= 0;
                    end
                end
                wait_configuration:begin
                    if(operating_config_done)begin
                        opeating_state <= update_period;
                    end
                end
                start_modulator_state: begin
                    if(write_request.ready)begin
                        write_request.dest <= PWM_BASE_ADDR;
                        modulator_status <= 1;
                        write_request.data <= modulator_on_config_register;
                        write_request.valid <= 1;
                        start_needed <= 0;
                        opeating_state <= wait_write_end;
                        next_state <= operating_idle;
                    end
                    
                end
                update_period: begin
                    if(s_phase_shift_1>period/2)begin
                        phase_shifts_data[1] = period;
                    end else if(s_phase_shift_1<-(period/2))begin
                        phase_shifts_data[1] = 0;
                    end else begin
                        phase_shifts_data[1] = period/2+s_phase_shift_1;
                    end 
                    if(write_request.ready)begin
                            write_request.data <= period;
                            write_request.dest <= PWM_BASE_ADDR + period_register_offset + (chain_counter+1)*'h100;
                            write_request.valid <= 1;
                            if(chain_counter == 1) begin
                                opeating_state <= wait_write_end;
                                next_state <= update_phase_shift;
                                chain_counter <= 0;
                            end else begin
                                chain_counter <= chain_counter +1;
                            end
                        end
                end
                update_phase_shift:begin
                    if(write_request.ready)begin
                        write_request.data <= phase_shifts_data[chain_counter];
                        write_request.dest <= PWM_BASE_ADDR + phase_shift_register_offset + (chain_counter+1)*'h100;
                        write_request.valid <= 1;
                        if(chain_counter == 1) begin
                            opeating_state <= wait_write_end;
                            next_state <= update_modulator;
                            chain_counter <= 0;
                        end else begin
                            chain_counter <= chain_counter +1;
                        end
                    end
                end
                update_modulator: begin
                    if(write_request.ready)begin
                        if(chain_counter == 1)begin
                            write_request.dest <= PWM_BASE_ADDR + modulator_registers_address[4+config_counter]+ (chain_counter+1)*'h100;
                            write_request.data <= modulator_registers_data[4+config_counter];
                        end else begin
                            write_request.dest <= PWM_BASE_ADDR + modulator_registers_address[config_counter]+ (chain_counter+1)*'h100;
                            write_request.data <= modulator_registers_data[config_counter];
                        end
                        
                        
                        write_request.valid <= 1;
                        if(config_counter==3)begin
                            config_counter <= 0;

                            if(chain_counter == 1) begin
                                if(start_needed) begin
                                    next_state <= start_modulator_state;
                                end else begin
                                    next_state <= operating_idle;
                                end
                                opeating_state <= wait_write_end;
                                chain_counter <= 0;
                            end else begin
                                chain_counter <= chain_counter +1;
                            end
                        end else begin
                            config_counter <= config_counter + 1;
                            opeating_state <= update_modulator;
                        end    
                    end
                end
                wait_write_end:begin
                    if(write_request.ready)begin
                        write_request.valid <= 0;
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
