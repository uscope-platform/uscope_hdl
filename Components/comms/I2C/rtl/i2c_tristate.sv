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

module I2C_tristate #(
    SCL_TIMEBASE_DELAY = 15,
    LOOPBACK_MODE = "TRUE"
)(
    input wire clock,
    input wire reset,
    inout wire SDA,
    inout wire SCL,
    axi_lite.slave axi_in,
    axi_stream.slave message_if
);

    wire scl_in, scl_out, sda_in, sda_out, scl_en, sda_en;
    
    generate
        if(LOOPBACK_MODE == "TRUE")begin
            assign SDA = sda_en ? sda_out : 1'b1;
            assign sda_in = SDA;

            assign SCL = scl_en & ~scl_out ? 0 : 1'b1;

            assign scl_in = SCL;
        end else begin

            assign SDA = (sda_out == 1'b0) ? 1'b0 : 1'bz;
            assign sda_in = SDA;

            assign SCL = (scl_out == 1'b0) ? 1'b0 : 1'bz;
            assign scl_in = SCL;  

        end
    endgenerate


        

    I2c_reader #(
        .SCL_TIMEBASE_DELAY(SCL_TIMEBASE_DELAY)
    )I2C_delay(
        .clock(clock),
        .reset(reset),
        .i2c_scl_in(scl_in),
        .i2c_scl_out(scl_out),
        .i2c_scl_out_en(scl_en),
        .i2c_sda_in(sda_in),
        .i2c_sda_out(sda_out),
        .i2c_sda_out_en(sda_en),
        .axi_in(axi_in),
        .message_if(message_if)
    );


endmodule
