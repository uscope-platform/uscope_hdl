// Copyright 2021 Filippo Savi
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

module axi_xbar #(
        parameter integer DATA_WIDTH = 32,
        parameter integer ADDR_WIDTH = 32,
        parameter integer ID_WIDTH = 4,
        parameter NM = 4,
        parameter NS = 8,
        parameter [ADDR_WIDTH-1:0] SLAVE_ADDR [NS-1:0] = '{NS{0}},
        parameter [ADDR_WIDTH-1:0] SLAVE_MASK [NS-1:0] =  '{NS{0}},
        parameter [0:0] OPT_LOWPOWER = 1,
        parameter OPT_LINGER = 4,
        parameter LGMAXBURST = 5
    ) (
        input wire clock,
        input wire reset,
        AXI.slave slaves [NM-1:0],
        AXI.master masters [NS-1:0]
    );

    localparam STROBE_WIDTH = DATA_WIDTH/8;

	axi_xbar_inner #(
        .C_AXI_DATA_WIDTH(DATA_WIDTH),
        .C_AXI_ADDR_WIDTH(ADDR_WIDTH),
        .C_AXI_ID_WIDTH(ID_WIDTH),
        .NM(NM),
        .NS(NS),
        .SLAVE_ADDR(SLAVE_ADDR),
        .SLAVE_MASK(SLAVE_MASK),
        .OPT_LOWPOWER(OPT_LOWPOWER),   
        .OPT_LINGER(OPT_LINGER),
        .LGMAXBURST(LGMAXBURST)
    ) inner_xbar(
        .clock(clock),
        .reset(reset),
        .slaves(slaves),
        .masters(masters)
	);


    

endmodule