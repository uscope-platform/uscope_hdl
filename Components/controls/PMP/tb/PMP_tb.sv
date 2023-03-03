

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
`include "axi_lite_BFM.svh"
`include "interfaces.svh"

module PMP_tb();
    reg clk, reset;

    axi_lite ctrl_axi();
    axi_lite axi_pwm();


    pre_modulation_processor #(
        .CONVERTER_SELECTION("DYNAMIC")
    ) UUT (
        .clock(clk),
        .reset(reset),
        .axi_in(ctrl_axi),
        .axi_out(axi_pwm)
    );


    PwmGenerator #(
       .BASE_ADDRESS(0)
    ) gen_checker(
        .clock(clk),
        .reset(reset),
        .ext_timebase(0),
        .fault(0),
        .axi_in(axi_pwm)
    );


    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 


    initial begin
        //Initial status
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;


    end

endmodule