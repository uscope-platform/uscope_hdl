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

module i2c_phy #(
    parameter int START_STOP_DELAY = 350
)(
    input wire clock,
    input wire sampling_tb,
    input wire i2c_sda_in,
    input wire start_beat,
    input wire last_beat,
    input wire immediate_stop,
    input wire start_read,
    input wire [7:0] write_data,
    input wire start_transfer,
    output reg transfer_done,
    output reg i2c_sda_out,
    output reg sda_enable,
    output reg scl_enable,
    output reg ack,
    output reg [7:0] read_data
);


    enum logic [3:0] {
        idle = 0,
        start=1,
        write_transmission = 2,
        read_reception = 3,
        wait_ack = 4,
        sample_ack = 5,
        send_ack = 6,
        stop=7
    } state = idle;

    reg [3:0] transfer_counter = 0;
    reg previous_timebase = 0;
    reg prev_sampling_tb = 0;

    initial begin
        i2c_sda_out = 0;
        transfer_done =0;
        scl_enable = 0;
        sda_enable = 0;
    end


    wire sampling_posedge;
    wire sampling_negedge;

    assign sampling_posedge = sampling_tb & ~prev_sampling_tb;
    assign sampling_negedge = ~sampling_tb & prev_sampling_tb;

    reg [15:0] wait_timer;
    always_ff @(posedge clock)begin
        if(state == start || state == stop)begin
            wait_timer <= wait_timer+1;
        end else begin
            wait_timer <= 0;
        end
    end

    reg[7:0] received_data = 0;

    reg stop_needed = 0;
    reg in_read = 0;
    always_ff @(posedge clock) begin
        prev_sampling_tb <= sampling_tb;

        transfer_done <=0;
        case (state)
            idle:begin
                ack <= 0;
                received_data <= 0;
                if(sampling_posedge)
                    transfer_counter <= 0;
                transfer_done <=0;
                if(transfer_counter == 0) i2c_sda_out <= 0;
                stop_needed <= last_beat;
                if(start_transfer) begin
                    if(start_beat)begin
                        state <= start;
                    end else begin
                        state <= write_transmission;
                    end
                end
                if(start_read)begin
                    sda_enable<= 0;
                    state <= read_reception;
                end
                if(immediate_stop) begin
                    state <= stop;
                end
            end
            read_reception:begin
                in_read <= 1;
                if(sampling_negedge)begin
                    received_data[7-transfer_counter] <= i2c_sda_in;
                    transfer_counter <= transfer_counter +1;
                    if(transfer_counter==7)begin
                        state <= wait_ack;
                    end
                end
            end
            send_ack: begin
                read_data <= received_data;
                if(sampling_posedge)begin
                    sda_enable<= 0;
                    if(stop_needed)begin
                        state <= stop;
                    end else begin
                        transfer_done <=1;
                        state <= idle;
                    end
                end
            end
            start:begin
                sda_enable<= 1;
                if(wait_timer == START_STOP_DELAY-1)begin
                    scl_enable <= 1;
                    state <= write_transmission;
                end
            end
            write_transmission: begin
                in_read <= 0;
                received_data <= 0;
                if(sampling_posedge)begin
                    i2c_sda_out <= write_data[7-transfer_counter];
                end
                if(sampling_negedge)begin
                    if(transfer_counter==7)begin
                        state <= wait_ack;
                    end
                    transfer_counter <= transfer_counter +1;
                end
            end
            wait_ack: begin
                if(sampling_posedge)begin
                    transfer_counter <= 0;
                    sda_enable <= 0;
                    if(in_read)begin
                        state <= send_ack;
                        sda_enable<= 1;
                    end else begin
                        state <= sample_ack;
                        sda_enable <= 0;
                    end
                end
            end
            sample_ack:begin
                if(sampling_negedge)begin
                    sda_enable<= 1;
                    if(stop_needed)begin
                        state <= stop;
                    end else begin
                        transfer_done <=1;
                        state <= idle;
                    end
                    ack <= !i2c_sda_in;
                end
            end
            stop:begin
                stop_needed<= 0;
                if(wait_timer>START_STOP_DELAY/2) begin
                    scl_enable<= 0;
                end
                if(wait_timer == START_STOP_DELAY-1)begin
                    sda_enable <= 0;
                    transfer_done <=1;
                    state <= idle;
                end
            end
        endcase
    end



endmodule
