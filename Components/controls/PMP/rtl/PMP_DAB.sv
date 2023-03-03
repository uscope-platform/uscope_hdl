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

module dab_pre_modulation_processor (
    input wire clock,
    input wire reset,
    input wire configure,
    input wire [3:0] update,
    input wire [1:0] modulation_type,
    input wire [15:0] period,
    input wire [15:0] duty_1,
    input wire [15:0] duty_2,
    input wire [15:0] phase_shift_1,
    input wire [15:0] phase_shift_2,
    output reg done,
    axi_stream.master write_request
);



    reg [31:0] config_data [3:0] = '{'h3f, 'h1, 0, 'h1100};
    reg [31:0] config_addr [3:0] = '{'h130, 'h138, 'h124, 'h0};
    


    reg [15:0] pri_ph_a_on;
    reg [15:0] pri_ph_a_off;
    reg [15:0] pri_ph_b_on;
    reg [15:0] pri_ph_b_off;
    reg [15:0] sec_ph_a_on;
    reg [15:0] sec_ph_a_off;
    reg [15:0] sec_ph_b_on;
    reg [15:0] sec_ph_b_off;

    wire [31:0] modulator_registers_data [8:0] = '{
        {16'b0, sec_ph_b_off},
        {16'b0, sec_ph_a_off},
        {16'b0, pri_ph_b_off},
        {16'b0, pri_ph_a_off},
        {16'b0, sec_ph_b_on},
        {16'b0, sec_ph_a_on},
        {16'b0, pri_ph_b_on},
        {16'b0, pri_ph_a_on},
        {16'b0, period}
    };
        
    wire [31:0] modulator_registers_address [8:0] = '{
            'h11C,
            'h118,
            'h114,
            'h110, 
            'h10C,
            'h108,
            'h104,
            'h100, 
            'h128
    };


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
        end else begin
            case (calculation_state)
                calc_idle_state: begin
                    update_needed <= update_needed | (|update);
                    done <= 0;
                    write_request.valid <= 0;

                    if(configure)begin
                        config_counter <= 0;
                        calculation_state <= configuration_state;
                    end
                    if(update_needed)begin
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
                end
                configuration_state:begin
                    update_needed <= update_needed | (|update);
                    if(write_request.ready)begin
                        write_request.dest <= config_addr[config_counter];
                        write_request.data <= config_data[config_counter];
                        write_request.valid <= 1;
                        if(config_counter==3)begin
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
                        write_request.dest <= modulator_registers_address[config_counter];
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
                pri_ph_a_on <= period/2 - duty_1/2;
                pri_ph_a_off <= period/2 + duty_1/2;
                pri_ph_b_on <= period/2 - duty_1/2;
                pri_ph_b_off <= period/2 + duty_1/2;
                sec_ph_a_on <= period/2 - duty_1/2 + phase_shift_1/2;
                sec_ph_a_off <= period/2 + duty_1/2 + phase_shift_1/2;
                sec_ph_b_on <= period/2 - duty_1/2 + phase_shift_1/2;
                sec_ph_b_off <= period/2 + duty_1/2 + phase_shift_1/2;
                sps_done <= 1;
            end


            if(dps_start)begin
                dps_start <= 0;
                pri_ph_a_on <= period/2 - duty_1/2;
                pri_ph_a_off <= period/2 + duty_1/2;
                pri_ph_b_on <= period/2 - duty_1/2 + phase_shift_2/2;
                pri_ph_b_off <= period/2 + duty_1/2 + phase_shift_2/2;

                sec_ph_a_on <= period/2 - duty_1/2 + phase_shift_1/2;
                sec_ph_a_off <= period/2 + duty_1/2 + phase_shift_1/2;
                sec_ph_b_on <= period/2 - duty_1/2 + phase_shift_1/2+phase_shift_2/2;
                sec_ph_b_off <= period/2 + duty_1/2 + phase_shift_1/2+phase_shift_2/2;
                sps_done <= 1;
            end
        end
    end
    
endmodule
