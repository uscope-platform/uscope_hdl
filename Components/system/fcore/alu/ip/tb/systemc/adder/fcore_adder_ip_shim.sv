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

// fcore_adder_ip with plain ports instead of axi_stream interfaces: Verilator can not have interface ports on the
// top level module, so this is what the SystemC testbench is connected to.
// The data ports are all 64 bits wide so that the testbench does not depend on the width of the stream, a narrower
// stream is zero extended. The adder is always enabled
module fcore_adder_ip_shim (
    input wire clock,
    input wire reset,
    input wire a_valid,
    output wire a_ready,
    input wire [63:0] a_data,
    input wire [31:0] a_dest,
    input wire [31:0] a_user,
    input wire a_tlast,
    input wire b_valid,
    output wire b_ready,
    input wire [63:0] b_data,
    input wire [31:0] b_dest,
    input wire [31:0] b_user,
    input wire b_tlast,
    input wire op_valid,
    output wire op_ready,
    input wire [63:0] op_data,
    input wire [31:0] op_dest,
    input wire [31:0] op_user,
    input wire op_tlast,
    output wire result_valid,
    input wire result_ready,
    output wire [63:0] result_data,
    output wire [31:0] result_dest,
    output wire [31:0] result_user,
    output wire result_tlast
);

    axi_stream a();
    axi_stream b();
    axi_stream op();
    axi_stream result();

    assign a.valid = a_valid;
    assign a.data = a_data[31:0];
    assign a.dest = a_dest;
    assign a.user = a_user;
    assign a.tlast = a_tlast;
    assign a_ready = a.ready;

    assign b.valid = b_valid;
    assign b.data = b_data[31:0];
    assign b.dest = b_dest;
    assign b.user = b_user;
    assign b.tlast = b_tlast;
    assign b_ready = b.ready;

    assign op.valid = op_valid;
    assign op.data = op_data[31:0];
    assign op.dest = op_dest;
    assign op.user = op_user;
    assign op.tlast = op_tlast;
    assign op_ready = op.ready;

    assign result_valid = result.valid;
    assign result_data = {32'b0, result.data};
    assign result_dest = result.dest;
    assign result_user = result.user;
    assign result_tlast = result.tlast;
    assign result.ready = result_ready;

    fcore_adder_ip dut (
        .clock(clock),
        .reset(reset),
        .enable(1'b1),
        .operand_a(a),
        .operand_b(b),
        .operation(op),
        .result(result)
    );

endmodule
