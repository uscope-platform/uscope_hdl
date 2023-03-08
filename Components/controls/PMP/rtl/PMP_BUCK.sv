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

module buck_pre_modulation_processor  #(
    PWM_BASE_ADDR = 0,
    N_PHASES = 4,
    N_PWM_CHANNELS = 1
)(
    input wire clock,
    input wire reset,
    input wire configure,
    input wire start,
    input wire stop,
    input wire [3:0] update,
    input wire [15:0] period,
    input wire [15:0] duty,
    input wire [15:0] phase_shifts[N_PHASES-1:0],
    output reg done,
    output reg modulator_status,
    axi_stream.master write_request
);

    localparam [15:0] deadtime = 5;

    reg [31:0] global_config_addr = 0;
    reg [31:0] global_config_data = 'h1100;

    reg [31:0] chain_config_data [4:0] = '{
        1,
        1,
        3,
        0,
        deadtime
    };

    reg [31:0] chain_config_addr [4:0] = '{
        'h20, // CHAIN CONTROL
        'h1C, // DEADTIME ENABLE
        'h18, // OUTPUT ENABLE
        'h10, // COUNTER STOP
        'h08 // DEADTIME
    };

    reg [31:0] phase_shift_offset = 'h14; // PHASE SHIFT
    reg [31:0] modulation_register_addr = 'h04; // COMPARE HIGH

    localparam  modulator_off = 0;
    localparam  modulator_on = 1;

    reg [31:0] modulator_on_config_register = 'h1128;
    
    reg update_needed = 0;
    reg [3:0] config_counter;
    
    typedef enum reg [3:0] {
        calc_idle_state = 0,
        configuration_state = 1,
        write_strobe = 2,
        update_modulator = 3,
        configure_shifts = 4
    } fsm_state;

    fsm_state calculation_state;
    fsm_state next_state;

    reg [15:0] phases_counter;

    // Determine the next state
    always @ (posedge clock) begin : main_fsm
        if (~reset) begin
            calculation_state <= calc_idle_state;
            config_counter <= 0;
            write_request.dest <= 0;
            write_request.data <= 0;
            write_request.valid <= 0;
            phases_counter <= 0;
            modulator_status <= modulator_off;
        end else begin
            chain_config_data[1] <= period;
            case (calculation_state)
                calc_idle_state: begin
                    update_needed <= update_needed | (|update);
                    done <= 0;
                    write_request.valid <= 0;

                    if(configure)begin
                        config_counter <= 0;
                        write_request.dest <= PWM_BASE_ADDR + global_config_addr;
                        write_request.data <= global_config_data;
                        write_request.valid <= 1;
                        next_state <=configuration_state;
                        calculation_state <= write_strobe;
                    end

                    if(update_needed & modulator_status==modulator_off)begin
                        calculation_state <= update_modulator;
                        update_needed <=0;
                    end

                     if(start) begin 
                        modulator_status <= modulator_on;
                        write_request.dest <= PWM_BASE_ADDR+ global_config_addr;
                        write_request.data <= modulator_on_config_register;
                        write_request.valid <= 1;
                    end

                    if(stop) begin 
                        modulator_status <= modulator_off;
                        write_request.dest <= PWM_BASE_ADDR+ global_config_addr;
                        write_request.data <= global_config_data;
                        write_request.valid <= 1;
                    end
                end
                configuration_state:begin
                    update_needed <= update_needed | (|update);
                    if(write_request.ready)begin
                        write_request.dest <= PWM_BASE_ADDR + 'h100*(phases_counter+1) + chain_config_addr[config_counter];
                        write_request.data <= chain_config_data[config_counter];
                        write_request.valid <= 1;
                        if(config_counter==4)begin
                            if(phases_counter == N_PHASES-1)begin
                                phases_counter <= 0;
                                next_state <= configure_shifts;
                                calculation_state <= write_strobe;
                                done <= 1;
                            end else begin
                                config_counter <= 0;
                                phases_counter <= phases_counter+1;
                            end
                        end else begin
                            next_state <= configuration_state;
                            config_counter <= config_counter+1;
                            calculation_state <= write_strobe;
                        end    
                    end
                end
                configure_shifts:begin
                    update_needed <= update_needed | (|update);
                    if(write_request.ready)begin
                        write_request.dest <= PWM_BASE_ADDR + 'h100*(phases_counter+1) + phase_shift_offset;
                        write_request.data <= phase_shifts[phases_counter];
                        write_request.valid <= 1;
                        if(phases_counter == N_PHASES-1)begin
                            next_state <= calc_idle_state;
                            calculation_state <= write_strobe;
                            phases_counter<= 0;
                            done <= 1;
                        end else begin
                            phases_counter <= phases_counter+1;
                            next_state <= configure_shifts;
                            calculation_state <= write_strobe;
                        end
                    end
                end
                write_strobe:begin
                    update_needed <= update_needed | (|update);
                    write_request.valid <= 0;
                    if(~write_request.ready)begin   
                        calculation_state <= next_state;    
                    end
                end

                update_modulator:begin
                    if(write_request.ready)begin
                        write_request.dest <= PWM_BASE_ADDR + 'h100*(phases_counter+1) + modulation_register_addr;
                        write_request.data <= duty;
                        write_request.valid <= 1;
                        if(phases_counter==N_PHASES-1)begin
                            calculation_state <= calc_idle_state;
                        end else begin
                            next_state <= update_modulator;
                            phases_counter <= phases_counter +1;
                            calculation_state <= write_strobe;
                        end    
                    end
                end
            endcase


        end
    end
endmodule
