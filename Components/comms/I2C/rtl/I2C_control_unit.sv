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

module I2CControlUnit #(parameter BASE_ADDRESS = 0)(
    input wire clock,
    input wire reset,
    input wire done,
    output reg        direction,
    output reg [31:0] prescale,
    output reg [7:0]  slave_adress,
    output reg [7:0]  register_adress,
    output reg [7:0]  data,
    output reg        start,
    output reg        timebase_enable,
    Simplebus.slave sb
);

    //FSM state registers
    reg [2:0] state;

    reg act_state_ended;


    reg [31:0]  latched_adress;
    reg [31:0] latched_writedata;

    // FSM states
    parameter idle_state = 0, act_state = 1, comm_start_state = 2, comm_in_progress_state=3;

    //latch bus writes
    always @(posedge clock) begin : sb_registration_logic
        if(~reset) begin
            latched_adress<=0;
            latched_writedata<=0;
        end else begin
            if(sb.sb_write_strobe) begin
                latched_adress <= sb.sb_address;
                latched_writedata <= sb.sb_write_data;
            end 
        end
    end


    // Determine the next state
    always @ (posedge clock) begin : control_state_machine
        if (~reset) begin
            state <= idle_state;
            sb.sb_read_data <= 0;
            act_state_ended <= 0;
            sb.sb_ready <= 1;
            data <= 0;
            prescale <= 1;
            timebase_enable <= 0;
            direction <= 0;
            register_adress <= 0;
            slave_adress <= 0;
            start <= 0;
        end else begin
            case (state)
                idle_state: //wait for command
                    if(sb.sb_write_strobe) begin
                        if(sb.sb_address==BASE_ADDRESS+32'h14)begin
                            state <= comm_start_state;
                        end else if(sb.sb_address == BASE_ADDRESS+31'h18)begin
                            state <= comm_start_state;
                        end else begin
                            state <= act_state;
                        end
                        sb.sb_ready <= 0;
                    end else
                        state <=idle_state;
                act_state: // Act on shadowed write
                    if(act_state_ended) begin
                        state <= idle_state;
                        sb.sb_ready <= 1;
                    end else begin
                        state <= act_state;
                    end
                comm_start_state:
                    state <= comm_in_progress_state;
                comm_in_progress_state: begin
                    if(done) begin
                        state <= idle_state;
                        sb.sb_ready <= 1;
                    end else begin
                        state <= comm_in_progress_state;
                    end 
                end
            endcase

            //act if necessary
            //State act_shadowed_state
            //State disable_pwm_state
            case (state)
                idle_state: begin
                        act_state_ended <= 0;
                    end
                act_state: begin
                    case (latched_adress)
                        //STATUS
                        BASE_ADDRESS+32'h00: begin
                        end
                        //CONTROL
                        BASE_ADDRESS+32'h04: begin
                            slave_adress <= latched_writedata[6:0];
                            direction <= latched_writedata[7];
                            timebase_enable <= latched_writedata[8];
                        end
                        //DATA
                        BASE_ADDRESS+32'h08: begin
                            register_adress <= latched_writedata[7:0];
                        end
                        //DATA
                        BASE_ADDRESS+32'h0C: begin
                            data <= latched_writedata[7:0];
                        end
                        //PRESCALE
                        BASE_ADDRESS+32'h10: begin
                            prescale[31:0] <= latched_writedata[31:0];
                        end
                        //AUTOMATED_Write
                        BASE_ADDRESS+32'h18: begin
                            register_adress <= latched_writedata[7:0];
                            slave_adress <= latched_writedata[15:8];
                            data <= latched_writedata[23:16];
                        end
                    endcase
                    act_state_ended<=1;
                    end
                comm_start_state:begin
                    start <= 1;
                    if(latched_adress==BASE_ADDRESS+31'h18) begin
							timebase_enable <= 1;
                            slave_adress <= latched_writedata[7:0];
                            register_adress <= latched_writedata[15:8];
                            data <= latched_writedata[23:16];
                    end
                end
                comm_in_progress_state:begin
                    start <= 0;
                end
            endcase
        end
    end
endmodule