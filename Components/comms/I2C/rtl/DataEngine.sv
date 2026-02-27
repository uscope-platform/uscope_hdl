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

module DataEngine #(parameter SETUP_DELAY = 35)(
    input wire clock,
    input wire timebase,
    input wire i2c_sda_in,
    input wire [7:0] data,
    input wire start_transfer,
    output reg transfer_done,
    output reg i2c_sda_out,
    output reg ack
);


    enum logic [2:0] {  
        idle = 0,
        transmission = 1,
        wait_ack = 2,
        sample_ack = 3
    } state = idle;

    reg busy = 0;
    reg [3:0] transfer_counter = 0;
    reg previous_timebase = 0;

    initial begin
        i2c_sda_out = 0;
        transfer_done =0;
    end

    wire tb_posedge;
    wire tb_negedge;

    assign tb_posedge = timebase& ~previous_timebase;
    assign tb_negedge = ~timebase& previous_timebase;

    always_ff @(posedge clock) begin
        previous_timebase <= timebase;
        case (state)
            idle:begin
                ack <= 0;
                if(tb_posedge) 
                    transfer_counter <= 0;
                transfer_done <=0;
                if(transfer_counter == 0) i2c_sda_out <= 0;
                if(start_transfer) begin
                    state <= transmission;
                end
            end
            transmission: begin
                if(tb_posedge)begin
                    if(transfer_counter==7)begin
                        transfer_done <=1;
                    end
                    transfer_counter <= transfer_counter +1;
                    i2c_sda_out <= data[7-transfer_counter];
                end           
                if(transfer_done) begin
                    state <= wait_ack;
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
                    state <= idle;
                    ack <= !i2c_sda_in;
                end
            end
            
        endcase
    end



endmodule