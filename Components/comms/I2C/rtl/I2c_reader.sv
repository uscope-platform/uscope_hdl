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
`include "interfaces.svh"

module I2c_reader #(
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
    axi_lite.slave axi_in,
    axi_stream.slave message_if
);

    wire [7:0] slave_address;
    wire [7:0] register_address;
    wire [31:0] period;
    wire timebase, direction, start;
    wire send_slave_address, send_register, send_data, done, timebase_enable;
    wire i2c_sda_data, i2c_sda_control;
    wire i2c_scl_control;

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


    enable_generator_core #(
        .COUNTER_WIDTH(16),
        .CLOCK_MODE("TRUE")
    ) tb_core(
        .clock(clock),
        .reset(reset),
        .gen_enable_in(timebase_enable),
        .period(period),
        .enable_out(timebase)
    );

    logic [31:0] cu_write_registers [0:0];
    logic [31:0] cu_read_registers [0:0];

    axil_simple_register_cu #(
        .N_READ_REGISTERS(1),
        .N_WRITE_REGISTERS(1),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hf)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axi_in)
    );

    assign cu_read_registers = cu_write_registers;
    assign period = cu_write_registers[0];
    
    
    assign direction = message_if.data;
    assign slave_address = message_if.dest;
    assign register_address = message_if.user;
    assign start = message_if.valid;

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
        .data(0),
        .send_slave_address(send_slave_address),
        .send_register(send_register),
        .send_data(send_data),
        .transfer_done(transfer_done),
        .i2c_sda(i2c_sda_data)
    );


endmodule


 /**
       {
        "name": "I2c_reader",
        "alias": "I2C_reader",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "control",
                "n_regs": ["1"],
                "description": "I2C peripheral control register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"timebase_enable",
                        "description": "Enable I2C peripheral timebase generator",
                        "n_fields":["1"],
                        "start_position": 0,
                        "length": 1
                    }
                ]
            },
            {
                "name": "timebase_div",
                "n_regs": ["1"],
                "description": "Diviso setting for the I2C timebase generator",
                "direction": "RW",
                "fields":[]
            }
        ]
    }  
    **/