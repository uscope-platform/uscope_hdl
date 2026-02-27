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

module tmp100 (
    input wire clock,
    input wire reset,
    input wire enable,
    inout wire SDA,
    inout wire SCL,
    axi_lite.slave axi_in
);

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

    wire [15:0] slave_addr;
    wire [15:0] reg_addr;
    wire [15:0] tx_data;
    reg [31:0] rx_data = 0;

    assign slave_addr = cu_write_registers[0];
    assign reg_addr = cu_write_registers[1];
    assign tx_data = cu_write_registers[2];
    assign cu_read_registers[2:0] = cu_write_registers[2:0];
    assign cu_read_registers[3] = rx_data;
    
    assign i2c_write.data = tx_data;
    assign i2c_write.dest = slave_addr;
    assign i2c_write.user = reg_addr;

    reg [31:0] transmission_ctr = 0;

    always_ff @(posedge clock)begin
        if(i2c_read.valid)begin
            rx_data <= i2c_read.data;
        end
        if(enable)begin
            i2c_write.valid <= 0;
            if(transmission_ctr  == 400000)begin
                transmission_ctr <= 0;
                i2c_write.valid <= 1;
            end else begin
                transmission_ctr <= transmission_ctr+1;
            end
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