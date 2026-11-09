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

// fp_fp32_to_fp64 with plain ports instead of axi_stream interfaces: Verilator can not
// have interface ports on the top level module, so this is what the SystemC testbench is connected to.
// The ports have the width of the streams, the testbench adapts to them
module fp_fp32_to_fp64_shim (
    input wire clock,
    input wire reset,
    input wire in_valid,
    output wire in_ready,
    input wire [31:0] in_data,
    input wire [31:0] in_dest,
    input wire [31:0] in_user,
    input wire in_tlast,
    output wire out_valid,
    input wire out_ready,
    output wire [63:0] out_data,
    output wire [31:0] out_dest,
    output wire [31:0] out_user,
    output wire out_tlast
);

    axi_stream #(.DATA_WIDTH(32)) in();
    axi_stream #(.DATA_WIDTH(64)) out();

    assign in.valid = in_valid;
    assign in.data = in_data;
    assign in.dest = in_dest;
    assign in.user = in_user;
    assign in.tlast = in_tlast;
    assign in_ready = in.ready;

    assign out_valid = out.valid;
    assign out_data = out.data;
    assign out_dest = out.dest;
    assign out_user = out.user;
    assign out_tlast = out.tlast;
    assign out.ready = out_ready;

    fp_fp32_to_fp64 dut (
        .clock(clock),
        .reset(reset),
        .in(in),
        .out(out)
    );

endmodule
