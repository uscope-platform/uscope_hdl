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

module i2c_phy #(parameter SETUP_DELAY = 35,START_STOP_DELAY = 350)(
    input wire clock,
    input wire timebase,
    input wire i2c_sda_in,
    input wire start_beat,
    input wire last_beat,
    input wire [7:0] data,
    input wire start_transfer,
    output reg transfer_done,
    output reg i2c_sda_out,
    output reg sda_enable,
    output reg scl_enable,
    output reg ack
);


    enum logic [2:0] {  
        idle = 0,
        start=1,
        transmission = 2,
        wait_ack = 3,
        sample_ack = 4,
        stop=5
    } state = idle;

    reg busy = 0;
    reg [3:0] transfer_counter = 0;
    reg previous_timebase = 0;

    initial begin
        i2c_sda_out = 0;
        transfer_done =0;
        scl_enable = 0;
        sda_enable = 0;
    end

    wire tb_posedge;
    wire tb_negedge;

    assign tb_posedge = timebase& ~previous_timebase;
    assign tb_negedge = ~timebase& previous_timebase;

    reg [15:0] wait_timer;
    always_ff @(posedge clock)begin
        if(state == start || state == stop)begin
            wait_timer <= wait_timer+1;
        end else begin
            wait_timer <= 0;
        end
    end


    reg stop_needed = 0;
    always_ff @(posedge clock) begin
        previous_timebase <= timebase;
        transfer_done <=0;
        case (state)
            idle:begin
                ack <= 0;
                if(tb_posedge) 
                    transfer_counter <= 0;
                transfer_done <=0;
                if(transfer_counter == 0) i2c_sda_out <= 0;
                if(start_transfer) begin
                    stop_needed <= last_beat;
                    if(start_beat)begin
                        state <= start;
                    end else begin
                        state <= transmission;
                    end
                end
            end
            start:begin
                sda_enable<= 1;
                if(wait_timer == START_STOP_DELAY-1)begin
                    scl_enable <= 1;
                    state <= transmission;
                end
            end
            transmission: begin
                if(tb_posedge)begin
                    if(transfer_counter==7)begin
                        state <= wait_ack;
                    end
                    transfer_counter <= transfer_counter +1;
                    i2c_sda_out <= data[7-transfer_counter];
                end
            end
            wait_ack: begin
                if(tb_posedge)begin
                    transfer_counter <= 0;
                    state <= sample_ack;
                end
            end
            sample_ack:begin
                if(tb_negedge)begin
                    transfer_done <=1;
                    if(stop_needed)begin
                        state <= stop;
                    end else begin
                        state <= idle;
                    end
                    
                    ack <= !i2c_sda_in;
                end
            end
            stop:begin
                if(wait_timer>START_STOP_DELAY/2) begin
                    scl_enable<= 0;
                end
                if(wait_timer == START_STOP_DELAY-1)begin
                    sda_enable <= 0;
                    state <= idle;
                end
            end
            
        endcase
    end



endmodule