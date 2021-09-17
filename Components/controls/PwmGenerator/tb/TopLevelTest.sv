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
`include "interfaces.svh"

module TopLevelTest (
    output wire [11:0] pwm_out
);

APB apb();
Simplebus s();
wire clk, rst;

Zynq_wrapper TEST(
    .APB(apb),
    .Clock(clk),
    .Reset(rst));
    
APB_to_Simplebus bridge(
    .PCLK(clk),
    .PRESETn(rst),
    .apb(apb),
    .spb(s));

 PwmGenerator PWM(
    .clock(clk),
    .reset(rst),
    .spb(s),
    .pwm_out(pwm_out) 
);

endmodule