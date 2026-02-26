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

module tmp100 (
    input wire clock,
    input wire reset,
    input wire enable,
    inout wire SDA,
    inout wire SCL,
    axi_lite.slave axi_in
);

    localparam N_REGISTERS = 3;
    reg [31:0] cu_write_registers [N_REGISTERS-1:0];
    reg [31:0] cu_read_registers [N_REGISTERS-1:0];


    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_REGISTERS),
        .N_WRITE_REGISTERS(N_REGISTERS),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hf)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axi_in)
    );

    axi_stream i2c_write();

    wire [7:0] slave_addr;
    wire [7:0] reg_addr;
    wire [7:0] data;

    assign slave_addr = cu_write_registers[0];
    assign reg_addr = cu_write_registers[1];
    assign data = cu_write_registers[2];

    wire [31:0] write_data;
    assign write_data = {data, slave_addr, reg_addr};
    
    assign i2c_write.data = write_data;

    reg [31:0] transmission_ctr = 0;

    always_ff @(posedge clock)begin
        if(enable)begin
            i2c_write.valid <= 0;
            if(transmission_ctr  == 100000)begin
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
        .message_if(i2c_write)
    );

endmodule