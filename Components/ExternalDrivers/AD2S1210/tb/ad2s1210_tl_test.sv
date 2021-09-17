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


module ad2s1210_tl_test (
    input wire clock,
    input wire reset,
    input wire R_SDO_RES,
    output wire R_SDI_RES,
    output wire R_WR,
    output wire R_SCK_RES,
    output wire R_A0,
    output wire R_A1,
    output wire R_RE0,
    output wire R_RE1,
    output wire R_SAMPLE,
    output wire R_RESET,
    Simplebus s
);
    
    Simplebus slave_1();
    Simplebus slave_2();
    axi_stream resolver_out();
    assign R_RESET = 1;
    
    wire SS;

    assign R_WR = SS;
    wire start_read;

    parameter BASE_ADDRESS = 'h43c00000;

    defparam xbar.SLAVE_1_LOW = BASE_ADDRESS;
    defparam xbar.SLAVE_1_HIGH = BASE_ADDRESS+'h100;
    defparam xbar.SLAVE_2_LOW = BASE_ADDRESS+'h100;
    defparam xbar.SLAVE_2_HIGH = BASE_ADDRESS+'h200;
    
    SimplebusInterconnect_M1_S2 xbar(
        .clock(clock),
        .master(s),
        .slave_1(slave_1),
        .slave_2(slave_2)
    );

    defparam test.BASE_ADDRESS = BASE_ADDRESS;
    ad2s1210 test(
        .clock(clock),
        .reset(reset),
        .read_angle(read_angle),
        .read_speed(read_speed),
        .MOSI(R_SDI_RES),
        .MISO(R_SDO_RES),
        .SS(SS),
        .SCLK(R_SCK_RES),
        .R_A({R_A1, R_A0}),
        .R_RES({R_RE1, R_RE0}),
        .R_SAMPLE(R_SAMPLE),
        .data_out(resolver_out),
        .sb(slave_1)
    );


    defparam tb_gen.BASE_ADDRESS = BASE_ADDRESS+'h100;
    enable_generator_2 tb_gen(
        .clock(clock),
        .reset(reset),
        .gen_enable_in(0),
        .enable_out_1(read_angle),
        .enable_out_2(read_speed),
        .sb(slave_2)
    );

endmodule