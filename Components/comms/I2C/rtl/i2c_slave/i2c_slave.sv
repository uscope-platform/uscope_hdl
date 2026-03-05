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

module i2c_slave #(
    parameter reg [7:0] SLAVE_ADDRESS = 8'h00
) (
    input wire clock,
    input wire scl_in,
    input wire [7:0] data_in,
    input wire sda_in,
    output reg sda_out,
    output reg sda_en,
    axi_stream.slave data_out
);


reg prev_scl, prev_sda;

always_ff @(posedge clock) begin
    prev_scl <= scl_in;
    prev_sda <= sda_in;
end

wire scl_posedge = scl_in &~prev_scl;
wire scl_negedge = ~scl_in & prev_scl;

wire start;
assign start = scl_in & ~sda_in & prev_sda;
wire stop;
assign stop =  scl_in & sda_in & ~prev_sda;



typedef enum logic [3:0] {
    idle = 0,
    address_phase = 1,
    register_phase = 2,
    rx_data_phase = 3,
    tx_data_phase = 4,
    wait_sda_release = 5,
    wait_rx_ack = 6,
    send_ack_phase = 7,
    receive_ack_phase = 8,
    wait_stop = 9
} i2c_slave_fsm;

i2c_slave_fsm state = idle;
i2c_slave_fsm next_state  = idle;

reg [7:0] bit_counter = 0;
reg [6:0] rx_slave_address = 0;
reg [7:0] rx_register = 0;
reg [7:0] rx_data = 0;

reg push_rx_result  = 0;

wire ack_out = SLAVE_ADDRESS ==rx_slave_address;

initial begin
    sda_en<= 0;
    sda_out<= 0;
    data_out.data = 0;
    data_out.dest = 0;
    data_out.valid = 0;
    data_out.tlast =  0;
end

always_ff @(posedge clock) begin
    push_rx_result <= 0;
    data_out.valid <= 0;
    case (state)
        idle: begin
            sda_en<= 0;
            if(start)begin
                state <= address_phase;
                rx_slave_address <= 0;
            end
        end
        address_phase: begin
            if(scl_posedge)begin
                if(bit_counter==7)begin
                    bit_counter <= 0;
                    if(sda_in) begin
                        next_state <=tx_data_phase;
                    end else begin
                        rx_register <= 0;
                        next_state <= register_phase;
                    end
                    state <= wait_sda_release;
                end else begin
                    rx_slave_address <= {rx_slave_address, sda_in};
                    bit_counter <= bit_counter+1;
                end
            end
        end
        register_phase: begin
            if(scl_posedge)begin
                if(bit_counter==7)begin
                    bit_counter <= 0;
                    next_state <= rx_data_phase;
                    state <= wait_sda_release;
                end else begin
                    bit_counter <= bit_counter+1;
                end
                rx_register <= {rx_register, sda_in};
            end
        end
        rx_data_phase: begin
            if(scl_posedge)begin
                if(bit_counter==7)begin
                    bit_counter <= 0;
                    next_state <= idle;
                    state <= send_ack_phase;
                    push_rx_result  <= 1;
                end else begin
                    bit_counter <= bit_counter+1;
                end
                rx_data <= {rx_data, sda_in};
            end
        end
        tx_data_phase: begin
            sda_en <= 1;
            if(~scl_in)begin
                sda_out  <= data_in[7-bit_counter];
            end
            if(scl_posedge)begin
                if(bit_counter == 7) begin
                    bit_counter <= 0;
                    state <= wait_rx_ack;
                end else begin
                    bit_counter <= bit_counter+1;
                end
            end
        end
        wait_rx_ack: begin
            if(scl_negedge) state <= receive_ack_phase;
        end
        wait_sda_release: begin
            sda_out <= 1;
            if(sda_in & scl_posedge) begin
                state <= send_ack_phase;
                sda_en <= 1;
            end
        end
        send_ack_phase: begin
            sda_out <= ~ack_out;
            if(ack_out)begin
                if(scl_negedge) begin
                    state <= next_state;
                    sda_en <= 0;
                end
            end else begin
                state <= idle;
            end
        end
        receive_ack_phase: begin
            sda_en <= 0;
            if(scl_posedge)begin
                if(~sda_in)
                    state <= tx_data_phase;
                else
                    state <= wait_stop;
            end
        end
        wait_stop: begin
            state <= idle;
        end
    endcase


    if(push_rx_result) begin
        data_out.data <= rx_data;
        data_out.dest <= rx_register;
        data_out.valid <= 1;
    end
end

endmodule
