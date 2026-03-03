// Copyright 2026 Filippo Savi
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

module tmp100 #(
    parameter RESOLUTION = 12,
    parameter RESOLUTION_BITS = RESOLUTION  -9,
    parameter N_SENSORS = 1,
    parameter [6:0] ADDRESSES [N_SENSORS-1:0]= '{default:0}
)(
    input wire clock,
    input wire reset,
    input wire enable,
    input wire trigger,
    inout wire SDA,
    inout wire SCL,
    axi_lite.slave axi_in,
    axi_stream.master temperature
);

    generate
        if (RESOLUTION < 9 || RESOLUTION > 12) begin : gen_res_check
            initial begin
                $error("FATAL: RESOLUTION parameter must be between 9 and 12. Received: %0d", RESOLUTION);
            end
        end
    endgenerate


    axi_stream i2c_write();
    axi_stream i2c_read();


    reg [31:0] transmission_ctr = 0;

    wire signed [11:0] raw_sensor_output;
    assign raw_sensor_output = i2c_read.data>>4;

    reg [1:0] resolution = 2'b11;

    typedef enum logic [3:0] {  
        idle = 0,
        resolution_config =1,
        read_setup = 2,
        wait_transmission_start = 3,
        wait_transmission_end = 4,
        wait_trigger = 5,
        read = 6
    } driver_state;
    
    reg [6:0] sensors_ctr = 0;

    driver_state state = idle;
    driver_state next_state = idle;

    always_ff @(posedge clock)begin
        i2c_write.valid <= 0;
        case (state)
            idle : begin
                if(enable && i2c_write.ready)begin
                    state <= resolution_config;
                end
            end
            resolution_config: begin
                if(sensors_ctr == N_SENSORS-1)begin
                    next_state <= read_setup;
                    sensors_ctr <= 0;
                end else begin
                    sensors_ctr <= sensors_ctr +1;
                    next_state <= resolution_config;
                end
                i2c_write.data <= {1'b0,RESOLUTION_BITS, 5'b0};
                i2c_write.dest <= ADDRESSES[sensors_ctr];
                i2c_write.user <= 1;
                i2c_write.valid <= 1;
                state <= wait_transmission_start;
            end
            read_setup: begin
                if(sensors_ctr == N_SENSORS-1)begin
                    next_state <= wait_trigger;
                    sensors_ctr <= 0;
                end else begin
                    sensors_ctr <= sensors_ctr +1;
                    next_state <= read_setup;
                end
                i2c_write.data <= 0;
                i2c_write.user <= 0;
                i2c_write.dest <= ADDRESSES[sensors_ctr];
                i2c_write.valid <= 1;
                state <= wait_transmission_start;
            end
            wait_transmission_start: begin
                if(~i2c_write.ready) 
                    state <= wait_transmission_end;
            end
            wait_transmission_end: begin
                i2c_write.valid <= 0;
                if(i2c_write.ready)begin
                    state <= next_state;
                end
            end
            wait_trigger: begin
                if(trigger)
                    state <= read;
            end
            read:begin
               if(sensors_ctr == N_SENSORS-1)begin
                    sensors_ctr <= 0;
                    next_state <= wait_trigger;
                end else begin
                    sensors_ctr <= sensors_ctr +1;
                    next_state <= read;
                end
                state <= wait_transmission_start;

                i2c_write.valid <= 1;
                i2c_write.dest <= {1'b1,8'(ADDRESSES[sensors_ctr])};
            end
        endcase

        if(i2c_read.valid)begin
            temperature.data <= (raw_sensor_output*125)/2;
            temperature.valid <= 1;
            temperature.dest <= 1;
        end
    end
    
    i2c_master_tristate i2c_interface(
        .clock(clock),
        .reset(reset),
        .SDA(SDA),
        .SCL(SCL),
        .transfer_req(i2c_write),
        .read_response(i2c_read)
    );

endmodule