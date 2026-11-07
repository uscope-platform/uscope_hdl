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

`timescale 10 ns / 1 ns

// fcore_reciprocal_ip with plain ports instead of axi_stream interfaces: Verilator can not have interface ports on the
// top level module, so this is what the SystemC testbench is connected to.
// The data ports are all 64 bits wide so that the testbench does not depend on the width of the stream, a narrower
// stream is zero extended. The IP is always enabled
module fcore_reciprocal_ip_shim (
    input wire clock,
    input wire reset,
    input wire a_valid,
    output wire a_ready,
    input wire [63:0] a_data,
    input wire [31:0] a_dest,
    input wire [31:0] a_user,
    input wire a_tlast,
    output wire result_valid,
    input wire result_ready,
    output wire [63:0] result_data,
    output wire [31:0] result_dest,
    output wire [31:0] result_user,
    output wire result_tlast
);

    axi_stream a();
    axi_stream result();

    assign a.valid = a_valid;
    assign a.data = a_data[31:0];
    assign a.dest = a_dest;
    assign a.user = a_user;
    assign a.tlast = a_tlast;
    assign a_ready = a.ready;
    assign result_valid = result.valid;
    assign result_data = {32'b0, result.data};
    assign result_dest = result.dest;
    assign result_user = result.user;
    assign result_tlast = result.tlast;
    assign result.ready = result_ready;

    fcore_reciprocal_ip dut (
        .clock(clock),
        .reset(reset),
        .enable(1'b1),
        .operand_a(a),
        .result(result)
    );

endmodule
