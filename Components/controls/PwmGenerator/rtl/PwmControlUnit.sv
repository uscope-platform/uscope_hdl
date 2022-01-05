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


module PwmControlUnit #(parameter BASE_ADDRESS = 'h43c00000, INITIAL_STOPPED_STATE = 0)(
    input wire        clock,
    input wire        reset,
    input wire        counter_status,
    // timebase generator
    output reg [2:0]  timebase_setting,
    output reg        timebase_enable,
    output reg        timebase_external_enable,
    output reg        counter_run,
    output reg        sync,
    output reg        stop_request,
    output reg [11:0] counter_stopped_state,
    Simplebus.slave sb,
    axi_lite.slave axi_in
);





    wire[31:0]int_readdata;
   

    RegisterFile Registers(
        .clk(clock),
        .reset(reset),
        .addr_a(BASE_ADDRESS-sb.sb_address),
        .data_a(sb.sb_write_data),
        .we_a(sb.sb_write_strobe),
        .q_a(int_readdata)
    );

    assign sb.sb_read_data = int_readdata;
    

    enum reg [2:0] {
        idle_state = 0,
        act_state = 1,
        soft_stop = 2
    }state;

    reg act_ended=0;


    reg [31:0]  latched_adress;
    reg [31:0] latched_writedata;


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
    always @ (posedge clock) begin
        if (~reset) begin
            timebase_setting <=0;
            timebase_enable <=0;
            timebase_external_enable <=0;
            sb.sb_ready <=1'b1;
            stop_request <= 0;
            counter_stopped_state <= INITIAL_STOPPED_STATE;
            counter_run <= 0;
            state <= idle_state;
        end else begin
            case (state)
                idle_state: //wait for command
                    if(sb.sb_write_strobe) begin
                        sb.sb_ready <=0;
                        state <= act_state;
                    end
                act_state: // Act on shadowed write
                    if(act_ended) begin
                        state <= idle_state;
                        sb.sb_ready <=1;
                    end
                soft_stop:
                    if(~|counter_status) begin
                        state <= idle_state;
                        stop_request<= 0;
                    end
            endcase
            //act if necessary
            //State act_state
            case (state)
                idle_state: begin
                    act_ended <= 0;
                    sync <= 0;
                end
                act_state: begin
                    case(latched_adress)
                        8'h00 : begin
                            if(latched_writedata[7])begin
                                sync <= 1; 
                            end else begin
                                if(~|counter_status) begin
                                    timebase_setting <= latched_writedata[2:0];
                                    timebase_enable <= latched_writedata[3];
                                    timebase_external_enable <= latched_writedata[4];
                                end
                                counter_run <= latched_writedata[5];
                                if(latched_writedata[6]) begin
                                    stop_request <= 1;
                                    state <= soft_stop;
                                end;
                                counter_stopped_state[11:0] <= latched_writedata[18:7];
                            end
                        end
                    endcase
                    act_ended<=1;
                end
            endcase
        end
    end
endmodule