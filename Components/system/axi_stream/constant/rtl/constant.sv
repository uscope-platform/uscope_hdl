
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


module axis_constant #(parameter BASE_ADDRESS = 'h43c00000, parameter CONSTANT_WIDTH = 32)(
    input wire        clock,
    input wire        reset,
    input wire        sync,
    axi_stream.master const_out,
    Simplebus.slave   sb
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
    enum reg {
        idle_state = 0,
        act_state = 1
    } state;
 

    reg [31:0] latched_adress;
    reg [31:0] latched_writedata;

    reg [31:0] constant_high_bytes;
    reg [31:0] constant_dest;

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
            const_out.valid <= 0;
            const_out.data <= 0;
            constant_dest <= 0;
            constant_high_bytes <= 0;
        end else begin
            case (state)
                idle_state: begin
                    const_out.valid<= 0;
                    if(sb.sb_write_strobe) begin
                        sb.sb_ready <=0;
                        state <= act_state;
                    end else
                        state <=idle_state;
                end
                act_state: begin
                    sb.sb_ready <=1;
                    if(act_state_ended) begin
                        state <= idle_state;
                    end else begin
                        state <= act_state;
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
                        'h00: begin
                            if(const_out.ready & sync) begin
                                const_out.data <= {constant_high_bytes, latched_writedata[31:0]};
                                const_out.dest <= constant_dest;
                                const_out.valid <= 1;
                                act_state_ended<=1;
                            end
                        end
                        'h04:begin
                            constant_high_bytes <= latched_writedata[31:0];
                            act_state_ended<=1;
                        end
                        'h08:begin
                            constant_dest <= latched_writedata[31:0];
                            act_state_ended<=1;
                        end
                    endcase
                    
                    end
            endcase
        end
    end



endmodule