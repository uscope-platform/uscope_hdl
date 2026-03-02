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
    parameter RESOLUTION_BITS = RESOLUTION  -9
)(
    input wire clock,
    input wire reset,
    input wire enable,
    input wire trigger,
    inout wire SDA,
    inout wire SCL,
    axi_lite.slave axi_in
);

    generate
        if (RESOLUTION < 9 || RESOLUTION > 12) begin : gen_res_check
            initial begin
                $error("FATAL: RESOLUTION parameter must be between 9 and 12. Received: %0d", RESOLUTION);
            end
        end
    endgenerate

    localparam N_REGISTERS = 4;
    reg [31:0] cu_write_registers [N_REGISTERS-1:0];
    reg [31:0] cu_read_registers [N_REGISTERS-1:0];

    wire trigger_transfer;

    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_REGISTERS),
        .N_WRITE_REGISTERS(N_REGISTERS),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hf),
        .N_TRIGGER_REGISTERS(1),
        .TRIGGER_REGISTERS_IDX({0})
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .trigger_out(trigger_transfer),
        .axil(axi_in)
    );

    axi_stream i2c_write();
    axi_stream i2c_read();

    wire [7:0] slave_addr;
    reg [31:0] rx_data = 0;

    assign slave_addr = cu_write_registers[0];
    assign cu_read_registers[2:0] = cu_write_registers[2:0];
    assign cu_read_registers[3] = rx_data;
    

    reg [31:0] transmission_ctr = 0;

    wire signed [11:0] raw_sensor_output;
    assign raw_sensor_output = i2c_read.data>>4;

    reg [1:0] resolution = 2'b11;

    enum logic [3:0] {  
        idle = 0,
        wait_resolution_config =1,
        resolution_config =2,
        wait_read_setup = 3,
        read_setup = 4,
        read = 5
    } state = idle;

    always_ff @(posedge clock)begin
        i2c_write.valid <= 0;
        case (state)
            idle : begin
                if(enable && i2c_write.ready)begin
                    state <= wait_resolution_config;
                    i2c_write.data <= {1'b0,RESOLUTION_BITS, 5'b0};
                    i2c_write.dest <= slave_addr;
                    i2c_write.user <= 1;
                    i2c_write.valid <= 1;
                end
            end
            wait_resolution_config :begin
                if(~i2c_write.ready) begin
                    state <= resolution_config;
                end
            end
            resolution_config: begin
                if(i2c_write.ready) begin
                    state <= wait_read_setup;
                    i2c_write.user <= 0;
                    i2c_write.dest <= slave_addr;
                    i2c_write.valid <= 1;
                end
            end
            wait_read_setup: begin
                 if(~i2c_write.ready) begin
                    state <= read_setup;
                end
            end
            read_setup: begin
                if(i2c_write.ready) begin
                    state <= read;
                end
            end
            read:begin
                if(trigger && i2c_write.ready)begin
                    i2c_write.valid <= 1;
                    i2c_write.dest <= {1'b1,slave_addr};
                end
            end
        endcase
        if(i2c_read.valid)begin
            rx_data <= (raw_sensor_output*125)/2;
        end
    end
    
    I2C_tristate i2c_interface(
        .clock(clock),
        .reset(reset),
        .SDA(SDA),
        .SCL(SCL),
        .transfer_req(i2c_write),
        .read_response(i2c_read)
    );

endmodule