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
    input wire [15:0] duty_1,
    input wire [15:0] duty_2,
    input wire [15:0] phase_shift_1,
    input wire [15:0] phase_shift_2,
    output reg done,
    axi_stream.master write_request
);


    reg [31:0] config_data [3:0] = '{'h3f, 'h1, 0, 'h1100};
    reg [31:0] config_addr [3:0] = '{'h130, 'h138, 'h124, 'h0};
    
    reg [31:0] modulator_on_config_register = 'h1128;
    reg [31:0] modulator_timebase_shift_addr = 'h12c;

    reg [2:0] config_counter;
    
    enum reg [3:0] {
        calc_idle_state = 0,
        configuration_state = 1,
        config_pulse_strobe = 2
    } calculation_state;

    // Determine the next state
    always @ (posedge clock) begin : calculation_fsm
        if (~reset) begin
            calculation_state <= calc_idle_state;
            config_counter <= 0;
            write_request.dest <= 0;
            write_request.data <= 0;
            write_request.valid <= 0;
        end else begin
            case (calculation_state)
                calc_idle_state: begin
                    done <= 0;
                    write_request.valid <= 0;
                    if(configure)begin
                        config_counter <= 0;
                        calculation_state <= configuration_state;
                    end
                end
                configuration_state:begin
                    if(write_request.ready)begin
                        write_request.dest <= config_addr[config_counter];
                        write_request.data <= config_data[config_counter];
                        write_request.valid <= 1;
                        if(config_counter==3)begin
                            calculation_state <= calc_idle_state;
                            done <= 1;
                        end else begin
                            calculation_state <= config_pulse_strobe;
                        end    
                    end
                end
                config_pulse_strobe:begin
                    write_request.valid <= 0;
                    if(~write_request.ready)begin   
                        config_counter <= config_counter+1;
                        calculation_state <= configuration_state;    
                    end
                end
            endcase
        end
    end
    

endmodule
