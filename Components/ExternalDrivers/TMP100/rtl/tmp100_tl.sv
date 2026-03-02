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

    localparam n_axi_slaves = 3;

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

    tmp100_standalone_reader reader (
        .clock(clock),
        .reset(reset),
        .SDA(SDA),
        .SCL(SCL),
        .control_axi(control_axi)
    );

endmodule