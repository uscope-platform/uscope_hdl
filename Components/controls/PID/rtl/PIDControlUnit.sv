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


module PIDControlUnit #(parameter BASE_ADDRESS = 'h43c00000, parameter DATA_WIDTH = 16)(
    input wire        clock,
    input wire        reset,

    // PID parameters
    output reg nonblocking_output,
    output reg [DATA_WIDTH-1:0] kP,
    output reg [7:0] kP_den,
    output reg [DATA_WIDTH-1:0] kI,
    output reg [7:0] kI_den,
    output reg [DATA_WIDTH-1:0] kD,
    output reg [7:0] kD_den,
    output reg signed [DATA_WIDTH-1:0] limit_out_up,
    output reg signed [DATA_WIDTH-1:0] limit_out_down,
    output reg signed [DATA_WIDTH-1:0] limit_int_up,
    output reg signed [DATA_WIDTH-1:0] limit_int_down,
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

    assign sb.sb_read_data = int_readdata;
    
    //FSM state registers
    reg [2:0] state;
    reg act_ended=0;
 

    reg [31:0]  latched_adress;
    reg [31:0] latched_writedata;


    // FSM states
    parameter idle_state = 0, act_state = 1;




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
            kP <= 0; 
            kI <= 0;
            kD <= 0;
            limit_out_up <= 16'sd32767;
            limit_out_down <= -16'sd32767;
            limit_int_up <= 16'sd32767;
            limit_int_down <= -16'sd32767;
            nonblocking_output <= 0;
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
                        act_state_ended <= 0;
                    end
                act_state: begin
                    case (latched_adress)
                        32'h00: begin
                            nonblocking_output <= latched_writedata[0];
                        end
                        32'h04: begin
                            kP <= latched_writedata[DATA_WIDTH-1:0];
                        end
                        32'h08: begin
                            kI <= latched_writedata[DATA_WIDTH-1:0];
                        end
                        32'h0C: begin
                            kD <= latched_writedata[DATA_WIDTH-1:0];
                        end
                        32'h10: begin
                            limit_out_up <= latched_writedata[DATA_WIDTH-1:0];
                        end
                        32'h14: begin
                            limit_out_down <= latched_writedata[DATA_WIDTH-1:0];
                        end
                        32'h18: begin
                            limit_int_up <= latched_writedata[DATA_WIDTH-1:0];
                        end
                        32'h1C: begin
                            limit_int_down <= latched_writedata[DATA_WIDTH-1:0];
                        end
                        32'h20: begin
                            kP_den <= latched_writedata[7:0];
                            kI_den <= latched_writedata[15:8];
                            kD_den <= latched_writedata[23:16];
                        end
                    endcase
                    act_state_ended<=1;
                    end
            endcase
        end
    end
endmodule