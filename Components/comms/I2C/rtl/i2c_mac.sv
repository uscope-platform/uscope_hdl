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

module i2c_mac #(parameter START_STOP_DELAY = 350, ACK_DELAY = 1600, BUS_FREE_DELAY = 300)(
    input wire clock,
    input wire transfer_step_done,
    input wire [7:0] incoming_data,
    output reg start_beat,
    output reg last_beat,
    output reg start_read,
    output reg start_transfer,
    output reg transfert_done,
    output reg [7:0] outgoing_data,
    axi_stream.slave transfer_req,
    axi_stream.master read_response
);

    reg [7:0] transfers_counter = 0;
    
    reg [15:0] bus_free_timer = 0;

    typedef enum logic [2:0]{
        idle_state = 0,
        slave_address_state = 1,
        register_address_state = 2,
        write_data_state = 3,
        read_data_state = 4,
        bus_free_state = 5
    }transfer_controller_fsm;

    transfer_controller_fsm state = idle_state;

    reg [7:0] data = 0;
    reg [7:0] slave_address = 0;
    reg direction = 0;
    reg [7:0] register_address = 0;

    initial begin
        start_beat = 0;
        last_beat = 0;
        start_transfer = 0;

        start_read = 0;
        transfert_done = 0;
    end

    assign transfer_req.ready = state == idle_state ;
    
    reg [31:0] read_value = 0;

    always_ff @ (posedge clock) begin : control_state_machine
        start_transfer <= 0;
        start_read <= 0;
        read_response.valid <= 0;
        case (state)
            idle_state: begin
                if(transfer_req.valid)begin
                    slave_address <=transfer_req.dest[6:0];
                    direction <= transfer_req.dest[8];
                    register_address <= transfer_req.user[7:0];
                    data <= transfer_req.data[7:0];
                    state <= slave_address_state;
                    start_beat <= 1;
                    start_transfer <= 1;
                end
                transfert_done <= 0;
            end
            slave_address_state: begin
                outgoing_data <= {slave_address, direction};
                if(transfer_step_done)begin
                    start_beat <= 0;
                    if(direction==0)begin
                        state <= register_address_state;
                        start_transfer <= 1;
                    end else begin
                        start_read<=1;
                        state<= read_data_state;
                    end
                end
            end
            register_address_state: begin
                outgoing_data <= register_address;
                if(transfer_step_done)begin
                    start_transfer <= 1;
                    last_beat <= 1;
                    if(direction==0)begin
                        state <= write_data_state;
                    end 
                end
            end
            write_data_state: begin
                last_beat <= 0;
                outgoing_data <= data;
                if(transfer_step_done)begin
                    state <= bus_free_state;
                end
            end
            read_data_state:begin
                last_beat <= 0;
                if(transfer_step_done)begin
                    if(transfers_counter== 1)begin
                        state <= bus_free_state;
                        read_response.data <=  32'({read_value, incoming_data});
                        read_response.valid <= 1;
                        read_value <= 0;
                        transfers_counter <= 0;
                    end else begin
                        read_value <= {read_value, incoming_data};
                        start_read <= 1;
                        last_beat <= 1;
                        transfers_counter<= transfers_counter+1;
                    end
                    
                end
            end
            bus_free_state: begin
                if(bus_free_timer == BUS_FREE_DELAY)begin
                    state <= idle_state;
                    bus_free_timer <= 0;
                    transfert_done <= 1;
                end else begin
                    bus_free_timer<= bus_free_timer+1;
                end
            end
        endcase
    end


endmodule