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

module I2c #(parameter FIXED_PERIOD ="FALSE", FIXED_PERIOD_WIDTH = 1000, SCL_TIMEBASE_DELAY = 15)(
    input wire clock,
    input wire reset,
    input wire i2c_scl_in,
    output wire i2c_scl_out,
    output wire i2c_scl_out_en,
    input wire i2c_sda_in,
    output wire i2c_sda_out,
    output wire i2c_sda_out_en,
    Simplebus.slave sb
);

    


    wire [7:0] data;
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


	generate
		if (FIXED_PERIOD =="FALSE") begin
			defparam tb_core.COUNTER_WIDTH = 16;
            defparam tb_core.CLOCK_MODE = "TRUE";
            //%%enable_generator_core%%
			enable_generator_core tb_core(
				.clock(clock),
				.reset(reset),
				.gen_enable_in(timebase_enable),
				.period(period),
				.enable_out(timebase)
			);
		end else begin
			defparam tb_core.COUNTER_WIDTH = 16;
            defparam tb_core.CLOCK_MODE = "TRUE";
			//%%enable_generator_core%%
			enable_generator_core tb_core(
				.clock(clock),
				.reset(reset),
				.gen_enable_in(timebase_enable),
				.period(FIXED_PERIOD_WIDTH),
				.enable_out(timebase)
			);
		end
	endgenerate


    defparam control_unit.BASE_ADDRESS = 0;
    I2CControlUnit control_unit(
        .clock(clock),
        .reset(reset),
        .done(done),
        .sb(sb),
        .direction(direction),
        .prescale(period),
        .slave_adress(slave_address),
        .register_adress(register_address),
        .data(data),
        .start(start)
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