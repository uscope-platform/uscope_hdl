// Copyright 2021 University of Nottingham Ningbo China
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

`timescale 10ns / 1ns
`include "interfaces.svh"


module SimplebusConfigurator #(N_CONFIG = 10)(
        input wire clock,
        input wire start,
        input wire [31:0] config_address[N_CONFIG-1:0],
        input wire [31:0] config_data[N_CONFIG-1:0],
        output reg done,
        Simplebus.master sb
    );

    enum reg [1:0] {IDLE = 0, WORKING = 1, WAIT_STATE =2} state;

    reg [$clog2(N_CONFIG)-1:0] config_counter = 0;

    always@(posedge clock)begin
        sb.sb_read_strobe <= 0;
        sb.sb_write_strobe <= 0;
        sb.sb_write_data <= 0;
        sb.sb_address <= 0;
        done <= 0;
        case (state)
            IDLE: begin
                if(start)begin
                    state <= WORKING;
                    config_counter <= N_CONFIG-1;
                end
            end
                
            WORKING: begin
                if(sb.sb_ready)begin
                    sb.sb_address <= config_address[config_counter][31:0];
                    sb.sb_write_data <= config_data[config_counter][31:0];
                    sb.sb_write_strobe <= 1;
                    if(config_counter==0)begin
                        state <= IDLE;
                        done <= 1;
                    end else begin
                        state <= WAIT_STATE;
                        config_counter <= config_counter - 1;
                    end
                end
            end
            WAIT_STATE: begin
                sb.sb_write_strobe <= 0;
                state <= WORKING;
            end
            default: begin
                state <= IDLE;
            end
        endcase
    end





endmodule
