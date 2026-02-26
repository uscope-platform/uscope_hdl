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

module tmp100_tl (
    inout wire SDA,
    inout wire SCL
);

    wire clock, reset, dma_done;
    AXI #(.ADDR_WIDTH(36)) fcore_rom_link();

    axi_lite control_axi();
    AXI #(.ID_WIDTH(2), .ADDR_WIDTH(49), .DATA_WIDTH(128)) uscope();

    zynqmp_PS_wrapper #(
        .FCORE_PRESENT(1)
    ) PS (
        .logic_clock(clock),
        .reset(reset),
        .axi_out(control_axi),
        .fcore_axi(fcore_rom_link),
        .scope(uscope),
        .dma_done(dma_done)
    );

    parameter [48:0] AXI_ADDRESSES [1:0] = '{
        'h400000000,
        'h400010000
    };
    axi_lite i2c_axi();
    axi_lite gpio_axi();

    axil_crossbar_interface #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(49),
        .NM(1),
        .NS(2),
        .SLAVE_ADDR(AXI_ADDRESSES),
        .SLAVE_MASK('{2{32'hf0000}})
    ) control_interconnect (
        .clock(clock),
        .reset(reset),
        .slaves('{control_axi}),
        .masters({
            i2c_axi,
            gpio_axi
        })
    );

    wire [31:0] control_word;

    gpio ctrl(
        .clock(clock),
        .reset(reset),
        .axil(gpio_axi),
        .gpio_i(control_word),
        .gpio_o(control_word)
    );

    tmp100 driver(
        .clock(clock),
        .reset(reset),
        .enable(control_word[0]),
        .SDA(SDA),
        .SCL(SCL),
        .axi_in(i2c_axi)
    );


endmodule