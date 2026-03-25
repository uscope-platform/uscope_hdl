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
`timescale 10ns / 1ns

module fault_management_unit #(
    int N_FAULTS = 6
)(
    input wire clock,
    input wire reset,
    input wire [N_FAULTS-1:0] fault_in,
    output wire fault_out,
    output reg clear_fault,
    axi_lite.slave axi_in
);

endmodule
