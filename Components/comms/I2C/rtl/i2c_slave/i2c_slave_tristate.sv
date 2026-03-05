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

module i2c_slave_tristate #(
    parameter reg [7:0] SLAVE_ADDRESS = 8'h00
) (
    input wire clock,
    input wire SCL,
    input wire [7:0] data_in,
    inout wire SDA,
    axi_stream.slave data_out
);


    wire  sda_en, sda_out, sda_in;

    assign SDA = sda_en  & (sda_out == 1'b0) ? 1'b0 : 1'bz;
    assign sda_in = SDA;


    i2c_slave #(
        .SLAVE_ADDRESS(SLAVE_ADDRESS)
    ) i2c_impl (
        .clock(clock),
        .scl_in(SCL),
        .data_in(data_in),
        .sda_in(sda_in),
        .sda_out(sda_out),
        .sda_en(sda_en),
        .data_out(data_out)
    );

endmodule
