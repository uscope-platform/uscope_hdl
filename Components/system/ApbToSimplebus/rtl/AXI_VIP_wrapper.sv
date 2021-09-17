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
`timescale 1 ns / 1 ps
`include "interfaces.svh"

module AXI_VIP_wrapper(
    APB apb,
    input wire clk,
    input wire rst);

 AXI_VIP AXI_VIP_i(
        .APB_M_0_paddr(apb.PADDR),
        .APB_M_0_penable(apb.PENABLE),
        .APB_M_0_pprot(apb.PPROT),
        .APB_M_0_prdata(apb.PRDATA),
        .APB_M_0_pready(apb.PREADY),
        .APB_M_0_psel(apb.PSEL),
        .APB_M_0_pslverr(apb.PSLVERR),
        .APB_M_0_pstrb(apb.PSTRB),
        .APB_M_0_pwdata(apb.PWDATA),
        .APB_M_0_pwrite(apb.PWRITE),
        .clk(clk),
        .rst(rst));
endmodule
