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

module I2c #(
    FIXED_PERIOD_WIDTH = 1000,
    SCL_TIMEBASE_DELAY = 15,
    PRAGMA_MKFG_MODULE_TOP = "I2C"
)(
    input wire clock,
    input wire reset,
    input wire i2c_scl_in,
    output wire i2c_scl_out,
    output wire i2c_scl_out_en,
    input wire i2c_sda_in,
    output wire i2c_sda_out,
    output wire i2c_sda_out_en,
    axi_stream.slave transfer_req,
    axi_stream.master read_response
);


    wire [7:0] write_data;
    wire [7:0] read_data;
    wire start_transfer;
    wire timebase;
    wire done;
    wire i2c_sda_data, i2c_sda_control;
    wire i2c_scl_control;
    wire transfer_done;
    wire start_beat, last_beat, start_read;

    reg delayed_timebase;
    reg previous_timebase;
    reg delay_counter_en,next_val;
    reg [15:0] delay_counter;

    assign i2c_sda_out = i2c_sda_data;
    assign i2c_scl_out = delayed_timebase; 

    assign i2c_scl_out_en = i2c_scl_control;
    assign i2c_sda_out_en = i2c_sda_control;


    always_ff @(posedge clock)begin
        if(~reset) begin
            delay_counter <= 0;
            previous_timebase <=0;
            delay_counter_en <= 0;
            next_val <= 0;
            delayed_timebase <= 0;    
        end else begin
            if(timebase & ~previous_timebase)begin
                delay_counter_en <=1;
                next_val <= 1;
            end else if(~timebase & previous_timebase)begin
                delay_counter_en <=1;
                next_val <= 0;
            end
            if(delay_counter_en)begin
                if(delay_counter ==SCL_TIMEBASE_DELAY)begin
                    delay_counter_en <= 0;
                    delayed_timebase <= next_val;
                    delay_counter <= 0;
                end else begin
                    delay_counter <= delay_counter +1;
                end
            end
            previous_timebase <= timebase;
        end
    end


    i2c_scl_generator #(
        .COUNTER_WIDTH(16)
    ) tb_core(
        .clock(clock),
        .reset(reset),
        .enable(i2c_scl_control),
        .period(FIXED_PERIOD_WIDTH),
        .timebase(timebase)
    );


    i2c_mac transfer_sequencer(
        .clock(clock),
        .transfer_step_done(transfer_done),
        .transfert_done(done),
        .transfer_req(transfer_req),
        .start_beat(start_beat),
        .start_read(start_read),
        .last_beat(last_beat),
        .start_transfer(start_transfer),
        .outgoing_data(write_data),
        .incoming_data(read_data),
        .read_response(read_response)
    );

    
    i2c_phy phy(
        .clock(clock),
        .timebase(timebase),
        .write_data(write_data),
        .start_beat(start_beat),
        .start_read(start_read),
        .last_beat(last_beat),
        .start_transfer(start_transfer),
        .transfer_done(transfer_done),
        .i2c_sda_in(i2c_sda_in),
        .i2c_sda_out(i2c_sda_data),
        .scl_enable(i2c_scl_control),
        .sda_enable(i2c_sda_control),
        .ack(),
        .read_data(read_data)
    );


endmodule