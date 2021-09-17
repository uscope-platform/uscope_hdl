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
//`include "interfaces.svh"

module ChainControlUnit #(parameter BASE_ADDRESS = 0, N_CHANNELS = 3, COUNTER_WIDTH=16)(
    input wire clock,
    input wire reset,
    input wire counter_running,
    output reg counter_run,
    output reg [15:0] timebase_shift,
    output reg [2:0] counter_mode,
    output reg [COUNTER_WIDTH-1:0] counter_start_data,
    output reg [COUNTER_WIDTH-1:0] counter_stop_data,
    output reg compare_write_strobe,
    output reg [2:0] compare_address,
    output reg [COUNTER_WIDTH-1:0] compare_data_in,
    output reg [1:0] output_enable_0,
	output reg [1:0] output_enable_1,
	output reg [1:0] output_enable_2,
    output reg [15:0] deadtime_0,
	output reg [15:0] deadtime_1,
	output reg [15:0] deadtime_2,
    output reg deadtime_enable_0,
	output reg deadtime_enable_1,
	output reg deadtime_enable_2,
    Simplebus.slave sb
);

    //FSM state registers
    reg [2:0] state;

    reg act_state_ended;


    reg [31:0]  latched_adress;
    reg [31:0] latched_writedata;


    reg dc_mode;
    reg [31:0] dc_mode_bottom_value;
    reg [31:0] dc_mode_top_value;

    // FSM states
    parameter idle_state = 0, act_state = 1;

    //latch bus writes
    always @(posedge clock) begin : sb_registration_logic
        if(~reset) begin
            latched_adress<=0;
            latched_writedata<=0;
        end else begin
            if(sb.sb_write_strobe & state == idle_state) begin
                latched_adress <= sb.sb_address;
                latched_writedata <= sb.sb_write_data;
            end 
        end
    end


    // Determine the next state
    always @ (posedge clock) begin : control_state_machine
        if (~reset) begin
            state <=idle_state;
            act_state_ended <= 0;
            dc_mode <= 0;
            counter_run <= 0;
            timebase_shift <= 0;
            counter_mode <= 0;
            compare_write_strobe <= 0;
            compare_address <= 0;
            compare_data_in <= 0;
            output_enable_0 <= 0;
            output_enable_1 <= 0;
            output_enable_2 <= 0;
            deadtime_0 <= 0;
            deadtime_1 <= 0;
            deadtime_2 <= 0;
            deadtime_enable_0 <= 0;
            deadtime_enable_1 <= 0;
            deadtime_enable_2 <= 0;
            counter_start_data <= 0;
            counter_stop_data <= 0;
            dc_mode_bottom_value <= 0;
            dc_mode_top_value <= {COUNTER_WIDTH{1'b1}};
            sb.sb_ready <= 1;
        end else begin
            case (state)
                idle_state: //wait for command
                    if(sb.sb_write_strobe) begin
                        sb.sb_ready <=0;
                        state <= act_state;
                    end else
                        state <=idle_state;
                act_state: // Act on shadowed write
                    if(act_state_ended) begin
                        state <= idle_state;
                        sb.sb_ready <=1;
                    end else begin
                        state <= act_state;
                    end
            endcase

            //act if necessary
            //State act_shadowed_state
            //State disable_pwm_state
            case (state)
                idle_state: begin
                        compare_write_strobe <= 0;
                        act_state_ended <= 0;
                    end
                act_state: begin
                    case (latched_adress)
                        //COMPARE LOW
                        BASE_ADDRESS+32'h00: begin
                            compare_write_strobe <=1;
                            compare_address <= 0;
                            compare_data_in <= latched_writedata[COUNTER_WIDTH-1:0];
                        end
                        BASE_ADDRESS+32'h04: begin
                            compare_write_strobe <=1;
                            compare_address <= 1;
                            compare_data_in <= latched_writedata[COUNTER_WIDTH-1:0];
                        end
                        BASE_ADDRESS+32'h08: begin
                            compare_write_strobe <=1;
                            compare_address <= 2;
                            compare_data_in <= latched_writedata[COUNTER_WIDTH-1:0];
                        end
                        //COMPARE HIGH
                        BASE_ADDRESS+32'h0C: begin
                            compare_write_strobe <=1;
                            compare_address <= 3;
                            if(~dc_mode) begin
                                compare_data_in <= latched_writedata[COUNTER_WIDTH-1:0];
                            end else begin
                                compare_data_in <= dc_mode_top_value-latched_writedata[COUNTER_WIDTH-1:0];
                            end
                        end
                        BASE_ADDRESS+32'h10: begin
                            compare_write_strobe <=1;
                            compare_address <= 4;
                            if(~dc_mode) begin
                                compare_data_in <= latched_writedata[COUNTER_WIDTH-1:0];
                            end else begin
                                compare_data_in <= dc_mode_top_value-latched_writedata[COUNTER_WIDTH-1:0];
                            end
                        end
                        BASE_ADDRESS+32'h14: begin
                            compare_write_strobe <=1;
                            compare_address <= 5;
                            if(~dc_mode) begin
                                compare_data_in <= latched_writedata[COUNTER_WIDTH-1:0];
                            end else begin
                                compare_data_in <= dc_mode_top_value-latched_writedata[COUNTER_WIDTH-1:0];
                            end
                        end
                        //DEADTIME
                        BASE_ADDRESS+32'h18: begin
                            if(~counter_running) deadtime_0 <= latched_writedata[15:0];
                        end
                        BASE_ADDRESS+32'h1C: begin
                            if(~counter_running) deadtime_1 <= latched_writedata[15:0];
                        end
                        BASE_ADDRESS+32'h20: begin
                            if(~counter_running) deadtime_2 <= latched_writedata[15:0];
                        end
                        //COUNTER LIMITS
                        BASE_ADDRESS+32'h24: begin
                            if(~counter_running) begin
                                if(~dc_mode) begin
                                    counter_start_data <= latched_writedata[COUNTER_WIDTH-1:0];
                                end else begin
                                    compare_write_strobe <=1;
                                    compare_address <= 6;
                                    compare_data_in <= latched_writedata[COUNTER_WIDTH-1:0];
                                    dc_mode_bottom_value <= latched_writedata[31:0];
                                    counter_start_data <=  latched_writedata[31:0];
                                end
                            end
                        end
                        BASE_ADDRESS+32'h28: begin
                            if(~counter_running) begin
                                if(~dc_mode) begin
                                    counter_stop_data <= latched_writedata[COUNTER_WIDTH-1:0];
                                end else begin
                                    compare_write_strobe <=1;
                                    compare_address <= 7;
                                    compare_data_in <= latched_writedata[COUNTER_WIDTH-1:0];
                                    dc_mode_top_value <= latched_writedata[31:0];
                                    counter_stop_data <= latched_writedata[31:0];
                                end
                            end
                        end
                        //COUNTER PHASE SHIFT
                        BASE_ADDRESS+32'h2C: begin
                            if(~counter_running) timebase_shift[15:0] <= latched_writedata[31:0];
                        end
                        //OUTPUT ENABLE
                        BASE_ADDRESS+32'h30: begin
                            output_enable_0 <= latched_writedata[1:0];
                            output_enable_1 <= latched_writedata[3:2];
                            output_enable_2 <= latched_writedata[5:4];
                        end
                        //DEADTIME_ENABLE
                        BASE_ADDRESS+32'h34: begin
                            deadtime_enable_0 <= latched_writedata[0];
                            deadtime_enable_1 <= latched_writedata[1];
                            deadtime_enable_2 <= latched_writedata[2];
                        end
                        //COUNTER CONTROLS
                        BASE_ADDRESS+32'h38: begin
                            if(~counter_running) begin
                                if(latched_writedata[3]) begin
                                    counter_mode <= 2;
                                    dc_mode <= 1;
                                end else begin
                                    counter_mode <= latched_writedata[2:0];
                                    dc_mode <= 0;
                                end
                            end
                        end
                        //DUTY CYCLE MODE BOTTOM VALUE
                        BASE_ADDRESS+32'h3C: begin

                        end
                        //DUTY CYCLE MODE TOP VALUE
                        BASE_ADDRESS+32'h40: begin
                        end
                    endcase
                    act_state_ended<=1;
                    end
            endcase
        end
    end
endmodule