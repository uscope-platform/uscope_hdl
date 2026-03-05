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

module i2c_master #(
    parameter int FIXED_PERIOD_WIDTH = 1000,
    parameter int SCL_TIMEBASE_DELAY = 15,
    parameter string PRAGMA_MKFG_MODULE_TOP = "I2C"
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
    axi_stream.master response
);


    wire [7:0] write_data;
    wire [7:0] read_data;
    wire start_transfer;
    wire timebase, sampling_tb;
    wire done;
    wire i2c_sda_data, i2c_sda_control;
    wire i2c_scl_control;
    wire transfer_done;
    wire start_beat, last_beat, start_read;


    assign i2c_sda_out = i2c_sda_data;
    assign i2c_scl_out = timebase;

    assign i2c_scl_out_en = i2c_scl_control;
    assign i2c_sda_out_en = i2c_sda_control;

    wire slave_ack, immediate_stop;

    i2c_scl_generator #(
        .COUNTER_WIDTH(16)
    ) tb_core(
        .clock(clock),
        .reset(reset),
        .enable(i2c_scl_control),
        .period(FIXED_PERIOD_WIDTH),
        .timebase(timebase),
        .sampling_tb(sampling_tb)
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
        .ack(slave_ack),
        .immediate_stop(immediate_stop),
        .response(response)
    );


    i2c_phy phy(
        .clock(clock),
        .timebase(timebase),
        .sampling_tb(sampling_tb),
        .write_data(write_data),
        .start_beat(start_beat),
        .start_read(start_read),
        .last_beat(last_beat),
        .immediate_stop(immediate_stop),
        .start_transfer(start_transfer),
        .transfer_done(transfer_done),
        .i2c_sda_in(i2c_sda_in),
        .i2c_sda_out(i2c_sda_data),
        .scl_enable(i2c_scl_control),
        .sda_enable(i2c_sda_control),
        .ack(slave_ack),
        .read_data(read_data)
    );


endmodule
