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

`timescale 10 ns / 1 ns
`include "interfaces.svh"


module trigger_hub_CU #(parameter BASE_ADDRESS = 'h43c00000, parameter N_TRIGGERS = 16)(
    input wire        clock,
    input wire        reset,
    output reg [N_TRIGGERS-1:0] trigger_out,
    output reg capture_ack,
    output reg [15:0] trigger_position,
    Simplebus.slave sb
);

    wire[31:0] int_readdata;
    reg act_state_ended;

    RegisterFile Registers(
        .clk(clock),
        .reset(reset),
        .addr_a(BASE_ADDRESS-sb.sb_address),
        .data_a(sb.sb_write_data),
        .we_a(sb.sb_write_strobe),
        .q_a(int_readdata)
    );

    assign sb.sb_read_data = sb.sb_read_valid ? int_readdata : 0;
    
    //FSM state registers
    reg [2:0] state;
    reg act_ended=0;
 

    reg [31:0]  latched_adress;
    reg [31:0] latched_writedata;


    // FSM states
    localparam idle_state = 0, act_state = 1;

    //latch bus writes
    always @(posedge clock) begin
        if(~reset) begin
            latched_adress<=0;
            latched_writedata<=0;
        end else begin
            
            if(sb.sb_write_strobe & state == idle_state) begin
                latched_adress <= sb.sb_address-BASE_ADDRESS;
                latched_writedata <= sb.sb_write_data;
            end else begin
                latched_adress <= latched_adress;
                latched_writedata <= latched_writedata;
            end
        end
    end


    // Determine the next state
    always @ (posedge clock) begin : control_state_machine
        if (~reset) begin
            state <=idle_state;
            act_state_ended <= 0;
            sb.sb_ready <= 1;

        end else begin
            sb.sb_read_valid <= 0;
            case (state)
                idle_state: //wait for command
                    if(sb.sb_read_strobe) begin
                        sb.sb_read_valid <= 1;
                    end else if(sb.sb_write_strobe) begin
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
                        trigger_out <= 0;
                        capture_ack <= 0;
                        act_state_ended <= 0;
                    end
                act_state: begin
                    case (latched_adress)
                        32'h00: begin
                            trigger_out[latched_writedata[31:0]-1] <= 1;
                        end
                        32'h04: begin
                            capture_ack <= latched_writedata[0];
                        end
                        32'h08: begin
                            trigger_position[15:0] <= latched_writedata[15:0];
                        end
                    endcase
                    act_state_ended<=1;
                    end
            endcase
        end
    end
endmodule