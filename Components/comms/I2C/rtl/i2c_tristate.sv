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

module I2C_tristate #(parameter FIXED_PERIOD ="FALSE", FIXED_PERIOD_WIDTH = 1000, SCL_TIMEBASE_DELAY = 15)(
    input wire clock,
    input wire reset,
    inout wire SDA,
    inout wire SCL,
    axi_lite.slave axi_in
);

    wire scl_in, scl_out, sda_in, sda_out;


    assign SDA = (sda_out == 1'b0) ? 1'b0 : 1'bz;
    assign sda_in = SDA;

    assign SCL = (scl_out == 1'b0) ? 1'b0 : 1'bz;
    assign scl_in = SCL;

        

    I2c #(
        .FIXED_PERIOD(FIXED_PERIOD), 
        .FIXED_PERIOD_WIDTH(FIXED_PERIOD_WIDTH),
        .SCL_TIMEBASE_DELAY(SCL_TIMEBASE_DELAY)
    )I2C_delay(
        .clock(clock),
        .reset(reset),
        .i2c_scl_in(scl_in),
        .i2c_scl_out(scl_out),
        .i2c_sda_in(sda_in),
        .i2c_sda_out(sda_out),
        .axi_in(axi_in)
    );


endmodule
