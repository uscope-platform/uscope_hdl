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

module tmp100_standalone_reader (
    input wire clock,
    input wire reset,
    inout wire SDA,
    inout wire SCL,
    axi_lite.slave control_axi
);

    localparam n_axi_slaves = 3;
    localparam n_sensors = 6;

    parameter [48:0] AXI_ADDRESSES [n_axi_slaves-1:0] = '{
        'h400000000,
        'h400010000,
        'h400020000
    };

    axi_lite gpio_axi();
    axi_lite tb_axi();
    axi_lite temperature_axi();

    axil_crossbar_interface #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(49),
        .NM(1),
        .NS(n_axi_slaves),
        .SLAVE_ADDR(AXI_ADDRESSES)
    ) control_interconnect (
        .clock(clock),
        .reset(reset),
        .slaves('{control_axi}),
        .masters({
            gpio_axi,
            tb_axi,
            temperature_axi
        })
    );

    wire [31:0] control_word;

    wire enable;
    assign enable = control_word[0];

    gpio ctrl(
        .clock(clock),
        .reset(reset),
        .axil(gpio_axi),
        .gpio_i(control_word),
        .gpio_o(control_word)
    );

    wire read_tmp;
    enable_generator #(
        .COUNTER_WIDTH(32)
    ) tb (
        .clock(clock),
        .reset(reset),
        .gen_enable_in(enable),
        .enable_out(read_tmp),
        .axil(tb_axi)
    );

    axi_stream temperature();

    tmp100 #(
        .RESOLUTION(12),
        .N_SENSORS(n_sensors),
        .ADDRESSES('{7'h4d, 7'h4c, 7'h48, 7'h49, 7'h4A, 7'h4E})
    ) driver(
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .trigger(read_tmp),
        .SDA(SDA),
        .SCL(SCL),
        .temperature(temperature)
    );

    (* keep="true" *) reg [31:0] current_temps [n_sensors-1:0];

    always_ff @(posedge  clock)begin
        if(temperature.valid)begin
            current_temps[temperature.dest] <=  temperature.data;
        end
    end


    wire [31:0] write_regs [n_sensors-1:0];

    axil_simple_register_cu #(
        .N_READ_REGISTERS(6),
        .N_WRITE_REGISTERS(6),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hff)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(current_temps),
        .output_registers(write_regs),
        .axil(temperature_axi)
    );


endmodule