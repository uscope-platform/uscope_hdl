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

module vsi_pre_modulation_processor  #(
    PWM_BASE_ADDR = 0,
    N_PWM_CHANNELS = 4,
    N_PARAMETERS = 13
)(
    input wire clock,
    input wire reset,
    input wire configure,
    input wire start,
    input wire stop,
    input wire [N_PWM_CHANNELS-1:0] update,
    input wire [15:0] period,
    input wire [15:0] modulation_parameters[N_PARAMETERS-1:0],
    output reg done,
    output reg modulator_status,
    axi_stream.master write_request
);

    
    wire [15:0] duty[N_PWM_CHANNELS-1:0];
    assign duty = modulation_parameters[N_PWM_CHANNELS-1:0];
    
    localparam  modulator_off = 0;
    localparam  modulator_on = 1;

    reg [31:0] config_data [2:0] = '{
        {N_PWM_CHANNELS{2'b11}},
        'h1,
        'h1100
    };

    reg [31:0] config_addr [2:0] = '{
        (3*N_PWM_CHANNELS+3)*4, 
        (3*N_PWM_CHANNELS+5)*4,
        'h0};
        
    reg [31:0] config_user [2:0] = '{
        1, 
        1,
        'h0};

    reg [15:0] modulator_registers_data [2*N_PWM_CHANNELS:0];
    reg [31:0] modulator_registers_address [2*N_PWM_CHANNELS:0];

    initial begin
        modulator_registers_address[0] =  (3*N_PWM_CHANNELS+1)*4;
        
        for(integer i = N_PWM_CHANNELS-1; i>=0; i--)begin
            modulator_registers_address[i+1] =  4*i;
        end
        for(integer i = 2*N_PWM_CHANNELS-1; i>N_PWM_CHANNELS-1; i--)begin
            modulator_registers_address[i+1] =  4*i;
        end
    end


    reg [31:0] modulator_on_config_register = 'h1128;
    
    reg update_needed = 0;
    reg calculate, calculation_done;
    reg [3:0] config_counter;
    
    typedef enum reg [3:0] {
        calc_idle_state = 0,
        configuration_state = 1,
        write_strobe = 2,
        update_modulator = 3
    } fsm_state;

    fsm_state calculation_state;
    fsm_state next_state;

    reg config_done = 0;

    // Determine the next state
    always @ (posedge clock) begin : main_fsm
        if (~reset) begin
            calculation_state <= calc_idle_state;
            config_counter <= 0;
            write_request.dest <= 0;
            write_request.data <= 0;
            write_request.user <= 0;
            write_request.tlast <= 0;
            write_request.valid <= 0;
            calculate <= 0;
            calculation_done <= 0;
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

                    if(update_needed & config_done)begin
                        calculate <= 1;
                        update_needed <=0;
                    end

                    if(calculation_done)begin
                        config_counter <= 0;
                        calculation_done <= 0;
                        calculation_state <= update_modulator;
                    end

                     if(start) begin 
                        modulator_status <= modulator_on;
                        write_request.dest <= PWM_BASE_ADDR;
                        write_request.user <= 0;
                        write_request.data <= modulator_on_config_register;
                        write_request.valid <= 1;
                    end

                    if(stop) begin 
                        modulator_status <= modulator_off;
                        write_request.dest <= PWM_BASE_ADDR;
                        write_request.user <= 0;
                        write_request.data <= config_data[0];
                        write_request.valid <= 1;
                    end
                end
                configuration_state:begin
                    update_needed <= update_needed | (|update);
                    if(write_request.ready)begin
                        write_request.dest <= PWM_BASE_ADDR + config_addr[config_counter];
                        write_request.user <= config_user[config_counter];
                        write_request.data <= config_data[config_counter];
                        write_request.valid <= 1;
                        if(config_counter==2)begin
                            calculation_state <= calc_idle_state;
                            config_done <= 1;
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
                    config_counter <= config_counter+1;
                    calculation_state <= next_state;
                end

                update_modulator:begin
                    if(write_request.ready)begin
                        write_request.dest <= PWM_BASE_ADDR + modulator_registers_address[config_counter];
                        write_request.user <= 1;
                        write_request.data <= modulator_registers_data[config_counter];
                        write_request.valid <= 1;
                        if(config_counter==2*N_PWM_CHANNELS)begin
                            calculation_state <= calc_idle_state;
                        end else begin
                            next_state <= update_modulator;
                            calculation_state <= write_strobe;
                        end    
                    end
                end
            endcase


            if(calculate)begin
                calculate <= 0;
                for(int i = 0; i<N_PWM_CHANNELS; i++)begin
                    modulator_registers_data[i+1] <= period/2 - duty[i]/2;
                    modulator_registers_data[i+N_PWM_CHANNELS+1] <= period/2 + duty[i]/2;
                end
                calculation_done <= 1;
            end
        end
    end
    

endmodule
