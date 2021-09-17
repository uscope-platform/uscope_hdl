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

`timescale 10ns / 1ns
`include "interfaces.svh"

module fCore_TL();
    
    parameter INSTRUCTION_STORE_SIZE = 4096;
    parameter INSTRUCTION_WIDTH = 20;
    parameter ALU_OPCODE_WIDTH = 4;
    parameter REGISTER_FILE_DEPTH = 12;

    wire logic_clock, core_clock, reset, run;
    
    APB apb();
    AXI fcore_axi();
    Simplebus spb();
    Simplebus s1();
    Simplebus s2();
    axi_stream port_a();
    axi_stream result();

    fCore_PS PS(
        .APB(apb),
        .fCore_axi(fcore_axi),
        .Logic_Clock(logic_clock),
        .Reset(reset)
    );

    APB_to_Simplebus sb_bridge(
        .PCLK(logic_clock),
        .PRESETn(reset),
        .apb(apb),
        .spb(spb)
    );

    SimplebusInterconnect_M1_S2 xbar(
        .clock(logic_clock),
        .master(spb),
        .slave_1(s1),
        .slave_2(s2)
    );

    gpio gpio (
        .clock(logic_clock),
        .reset(reset),
        .gpio_o(run),
        .sb(s1)
    );

    fCore core(
        .clock(logic_clock),
        .reset(reset),
        .run(run),
        .sb(s2),
        .axi(fcore_axi)
    );
    

endmodule
