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
    axi_stream.slave message_if
);


    reg [7:0] data;
    reg [7:0] slave_address;
    reg [7:0] register_address;
    reg direction, start;
    wire timebase;
    wire send_slave_address, send_register, send_data, done, timebase_enable;
    wire i2c_sda_data, i2c_sda_control;
    wire i2c_scl_control;
    wire transfer_done;

    reg delayed_timebase;
    reg previous_timebase;
    reg delay_counter_en,next_val;
    reg [15:0] delay_counter;

    assign i2c_sda_out = i2c_sda_data;
    assign i2c_scl_out = delayed_timebase; 

    assign i2c_scl_out_en = ~i2c_scl_control;
    assign i2c_sda_out_en = ~i2c_sda_control;


    always@(posedge clock)begin
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

    reg in_flight = 0;

    initial begin
        message_if.ready = 1;
    end
    always_ff @(posedge clock)begin
        start <= 0;
        if(message_if.valid  &  ~in_flight)begin
            direction  <= message_if.data[24];
            slave_address <= message_if.data[15:8];
            register_address <= message_if.data[7:0];
            data <= message_if.data[23:16];
            start <= 1;
            in_flight <= 1;
            message_if.ready <= 0;
        end
        if(done)begin
            in_flight <= 0;
            message_if.ready <= 1;
        end
    end

    enable_generator_core #(
        .COUNTER_WIDTH(16),
        .CLOCK_MODE("TRUE")
    ) tb_core(
        .clock(clock),
        .reset(reset),
        .gen_enable_in(timebase_enable),
        .period(FIXED_PERIOD_WIDTH),
        .enable_out(timebase)
    );


    TransferController TC(
        .clock(clock),
        .reset(reset),
        .start_transfert(start),
        .timebase(timebase),
        .transfer_step_done(transfer_done),
        .ack(i2c_sda_in),
        .send_slave_address(send_slave_address),
        .send_register_address(send_register),
        .send_data(send_data),
        .i2c_sda_control(i2c_sda_control),
        .i2c_scl_control(i2c_scl_control),
        .transfert_done(done),
        .timebase_enable(timebase_enable)
    );

    
    DataEngine DE(
        .clock(clock),
        .reset(reset),
        .timebase(timebase),
        .direction(direction),
        .slave_address(slave_address),
        .register_address(register_address),
        .data(data),
        .send_slave_address(send_slave_address),
        .send_register(send_register),
        .send_data(send_data),
        .transfer_done(transfer_done),
        .i2c_sda(i2c_sda_data)
    );


endmodule