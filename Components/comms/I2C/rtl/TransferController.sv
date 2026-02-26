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

module TransferController #(parameter START_STOP_DELAY = 350, ACK_DELAY = 1600, BUS_FREE_DELAY = 300)(
    input wire clock,
    input wire reset,
    
    input wire transfer_step_done,
    input wire ack,
    output reg timebase_enable,
    output reg start_transfer,
    output reg i2c_sda_control,
    output reg i2c_scl_control,
    output reg transfert_done,
    output reg [7:0] outgoing_data,
    axi_stream.slave write_req
);

    
    reg wait_for_ack, wait_timer_enabled;
    
    reg [15:0] wait_timer;

    typedef enum logic [2:0]{
        idle_state = 0,
        start_state = 1,
        slave_address_state = 2,
        register_address_state = 3,
        data_state_state = 4,
        wait_ack_state = 5,
        stop_state = 6,
        bus_free_state = 7
    }transfer_controller_fsm;

    transfer_controller_fsm state = idle_state;
    transfer_controller_fsm next_phase = idle_state;

    reg [7:0] data = 0;
    reg [7:0] slave_address = 0;
    reg [7:0] register_address = 0;

    always_ff @(posedge clock)begin
        if(~reset)begin
            wait_timer <= 0;
        end else begin
            if(wait_timer_enabled)begin
                wait_timer <= wait_timer+1;
            end else begin
                wait_timer <= 0;
            end
        end
    end

    // Determine the next state
    always_ff @ (posedge clock) begin : control_state_machine
        if (~reset) begin
            start_transfer <= 0;
            wait_for_ack <= 0;
            i2c_sda_control <= 1;
            timebase_enable <= 0;
            i2c_scl_control <= 1;
            transfert_done <= 0;
            wait_timer_enabled <=0;
        end else begin
            case (state)
                idle_state: begin
                    if(write_req.valid)begin
                        slave_address <={write_req.dest[6:0], 1'b0};
                        register_address <= write_req.user[7:0];
                        data <= write_req.data[7:0];
                        write_req.ready <= 0;
                        state <= start_state;
                        i2c_sda_control <=0;
                    end
                    wait_for_ack <= 0;
                    transfert_done <= 0;
                    wait_timer_enabled <=0;
                end
                start_state: begin
                    if(wait_timer == START_STOP_DELAY)begin
                        state <= slave_address_state;
                        i2c_scl_control <= 0;
                        timebase_enable <= 1;
                    end
                    wait_timer_enabled <=1;
                end
                slave_address_state: begin
                    wait_for_ack <= 0;
                    i2c_sda_control <= 0;
                    wait_timer_enabled <=0;
                    start_transfer <= 1;
                    outgoing_data <= slave_address;
                    if(transfer_step_done)begin
                        start_transfer <= 0;
                        wait_for_ack <= 1;
                        wait_timer_enabled <=1;
                        state <= wait_ack_state;
                        next_phase <= register_address_state;
                    end
                end
                register_address_state: begin
                    wait_for_ack <= 0;
                    i2c_sda_control <= 0;
                    wait_timer_enabled <=0;
                    start_transfer <= 1;
                    outgoing_data <= register_address;
                    if(transfer_step_done)begin
                        start_transfer <= 0;
                        wait_for_ack <= 1;
                        wait_timer_enabled <=1;
                        state <= wait_ack_state;
                        next_phase <= data_state_state;
                    end
                end
                data_state_state: begin
                    wait_for_ack <= 0;
                    i2c_sda_control <= 0;
                    start_transfer <= 1;
                    outgoing_data <= data;
                    if(transfer_step_done)begin
                        start_transfer <= 0;
                        wait_for_ack <= 1;
                        wait_timer_enabled <=1;
                        state <= wait_ack_state;
                        next_phase <= stop_state;
                    end
                end
                wait_ack_state: begin
                    if(wait_timer > 540) begin
                        i2c_sda_control <= 1;
                    end
                    if(wait_timer==ACK_DELAY) begin
                        wait_timer_enabled <=0;
                        if(ack)
                            state <= next_phase;
                        else
                            state <= next_phase;
                    end 
                end
                stop_state: begin
                    wait_timer_enabled <=1;
                    i2c_sda_control <= 0;
                    if(wait_timer == 157) i2c_scl_control <= 1;
                    if(wait_timer == START_STOP_DELAY)begin
                        state <= bus_free_state;
                        timebase_enable <= 0;
                        wait_timer_enabled <= 0;
                        i2c_sda_control <= 1;
                    end
                end
                bus_free_state: begin
                    wait_timer_enabled <= 1;
                    if(wait_timer == BUS_FREE_DELAY)begin
                        state <= idle_state;
                        write_req.ready <= 0;
                        transfert_done <= 1;
                    end
                end
            endcase
        end
    end


endmodule