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


    parameter [48:0] AXI_ADDRESSES [n_axi_slaves-1:0] = '{
        'h400000000,
        'h400010000,
        'h400020000
    };

    axi_lite i2c_axi();
    axi_lite gpio_axi();
    axi_lite tb_axi();

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
            i2c_axi,
            gpio_axi,
            tb_axi
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

    tmp100 driver(
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .trigger(read_tmp),
        .SDA(SDA),
        .SCL(SCL),
        .axi_in(i2c_axi)
    );


endmodule