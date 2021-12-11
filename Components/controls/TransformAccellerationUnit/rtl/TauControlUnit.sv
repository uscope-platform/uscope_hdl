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

module TauControlUnit #(parameter BASE_ADDRESS = 'h43c00000)(
    input wire        clock,
    input wire        reset,
    Simplebus.slave   spb,
    output reg         disable_direct_chain_mode,
    output reg         disable_inverse_chain_mode,
    output reg         soft_reset
);



    assign spb.sb_read_data = spb.sb_read_valid ? readback_data : 0;
    
    RegisterFile Registers(
        .clk(clock),
        .reset(reset),
        .addr_a(BASE_ADDRESS-spb.sb_address),
        .data_a(spb.sb_write_data),
        .we_a(spb.sb_write_strobe),
        .q_a(readback_data)
    );

    //Timer state registers
    reg timerEnabled=0;
    //FSM state registers
    reg state =0;
    reg act_state_ended=0;

    reg [7:0]  latched_adress;
    reg [31:0] latched_writedata;

    reg [31:0] readback_data;

    // FSM states
    parameter wait_state = 0, act_state = 1;

    //assign latched_adress = spb.sb_address;
    //assign latched_writedata = spb.sb_write_data;
    
    //latch bus writes
    always @(posedge clock or negedge reset) begin
        if(~reset) begin
            latched_adress<=0;
            latched_writedata<=0;
        end else begin
            if(spb.sb_write_strobe & state == wait_state) begin
                latched_adress <= spb.sb_address;
                latched_writedata <= spb.sb_write_data;
            end else begin
                latched_adress <= latched_adress;
                latched_writedata <= latched_writedata;
            end
        end
    end


    // Determine the next state
    always @ (posedge clock or negedge reset) begin
        if (~reset) begin
            spb.sb_ready <=1'b1;
            soft_reset <=0;
            disable_direct_chain_mode <= 0;
            disable_inverse_chain_mode <= 0;
            state <= wait_state;
        end else begin

            case (state)
                wait_state: //wait for command
                    if(spb.sb_read_strobe) begin
                        spb.sb_read_valid <= 1;
                    end else if(spb.sb_write_strobe) begin
                        spb.sb_ready <=0;
                        state <= act_state;
                    end else 
                        state <=wait_state;
                act_state: // Act on shadowed write
                    if(act_state_ended) begin
                        spb.sb_ready <=1;
                        state <= wait_state;
                    end else begin
                        state <= act_state;
                    end
            endcase

            //act if necessary
            case (state)
                wait_state: begin 
                        act_state_ended <=0;

                    end
                act_state: begin
                    case (latched_adress-BASE_ADDRESS)
                        8'h0: begin
                            disable_direct_chain_mode <= latched_writedata[0];
                            disable_inverse_chain_mode <= latched_writedata[1];
                            soft_reset <= latched_writedata[2];
                        end
                    endcase
                    act_state_ended<=1;
                    end
            endcase

        end
    end

endmodule