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
`timescale 10ns / 1ns

module fcore_multiplier_ip (
    input wire clock,
    input wire reset,
    input wire enable,
    axi_stream.slave operand_a,
    axi_stream.slave operand_b,
    axi_stream.master result 
);

    axi_stream enabled_operand_a();
    assign enabled_operand_a.valid = operand_a.valid & enable;
    assign enabled_operand_a.data = operand_a.data;
    assign enabled_operand_a.dest = operand_a.dest;
    assign enabled_operand_a.user = operand_a.user;
    assign enabled_operand_a.tlast = operand_a.tlast;
    assign operand_a.ready = enabled_operand_a.ready & enable;


    axi_stream enabled_operand_b();
    assign enabled_operand_b.valid = operand_b.valid & enable;
    assign enabled_operand_b.data = operand_b.data;
    assign enabled_operand_b.dest = operand_b.dest;
    assign enabled_operand_b.user = operand_b.user;
    assign enabled_operand_b.tlast = operand_b.tlast;
    assign operand_b.ready = enabled_operand_b.ready & enable;


`ifdef VERILATOR
    // Model of the Xilinx floating point IP for Verilator, which can not run it. The operands are widened to double
    // with fp_fp32_to_fp64, multiplied in double precision with the real system functions and narrowed to float with
    // fp_fp64_to_fp32. The latency is the one of the IP: 2 + 1 + 2 = 5 cycles.
    // A double has more than twice the precision of a float plus two bits, so rounding the double product to float gives
    // the correctly rounded float product. A denormal result is flushed to zero and the payload of a NaN is not kept.
    // As in the IP, a result needs both operands to be valid at the same time, it carries the user of operand a, its dest
    // and tlast are 0 and nothing is held back: result.ready is not used. As in the generated wrapper, the ready of the
    // inputs is 0.

    wire all_valid = enabled_operand_a.valid & enabled_operand_b.valid;

    assign enabled_operand_a.ready = 1'b0;
    assign enabled_operand_b.ready = 1'b0;

    axi_stream #(.DATA_WIDTH(32)) narrow_a();
    axi_stream #(.DATA_WIDTH(32)) narrow_b();
    axi_stream #(.DATA_WIDTH(64)) wide_a();
    axi_stream #(.DATA_WIDTH(64)) wide_b();

    assign narrow_a.valid = all_valid;
    assign narrow_a.data = enabled_operand_a.data;
    assign narrow_a.user = enabled_operand_a.user;
    assign narrow_a.dest = 0;
    assign narrow_a.tlast = 1'b0;

    assign narrow_b.valid = all_valid;
    assign narrow_b.data = enabled_operand_b.data;
    assign narrow_b.user = 0;
    assign narrow_b.dest = 0;
    assign narrow_b.tlast = 1'b0;

    assign wide_a.ready = 1'b1;
    assign wide_b.ready = 1'b1;

    fp_fp32_to_fp64 widen_a (
        .clock(clock),
        .reset(reset),
        .in(narrow_a),
        .out(wide_a)
    );

    fp_fp32_to_fp64 widen_b (
        .clock(clock),
        .reset(reset),
        .in(narrow_b),
        .out(wide_b)
    );

    axi_stream #(.DATA_WIDTH(64)) product();

    reg        product_valid = 0;
    reg [63:0] product_data;
    reg [31:0] product_user;

    always_ff @(posedge clock) begin
        if (~reset) begin
            product_valid <= 0;
        end else begin
            product_valid <= wide_a.valid & wide_b.valid;
            product_data <= $realtobits($bitstoreal(wide_a.data) * $bitstoreal(wide_b.data));
            product_user <= wide_a.user;
        end
    end

    assign product.valid = product_valid;
    assign product.data = product_data;
    assign product.user = product_user;
    assign product.dest = 0;
    assign product.tlast = 1'b0;

    fp_fp64_to_fp32 narrow_product (
        .clock(clock),
        .reset(reset),
        .in(product),
        .out(result)
    );
`else
    vivado_axis_v1_0 #( .TDATA_NUM_BYTES(4), .TDEST_WIDTH(32), .TUSER_WIDTH(32)) a();
    vivado_axis_v1_0 #( .TDATA_NUM_BYTES(4), .TDEST_WIDTH(32), .TUSER_WIDTH(32)) b();
    vivado_axis_v1_0 #( .TDATA_NUM_BYTES(4), .TDEST_WIDTH(32), .TUSER_WIDTH(32)) op();
    vivado_axis_v1_0 #( .TDATA_NUM_BYTES(4), .TDEST_WIDTH(32), .TUSER_WIDTH(32)) res();



    amd_axi_stream_converter_slave  a_translator(
        .in(enabled_operand_a),
        .out(a)
    );

    amd_axi_stream_converter_slave  b_translator(
        .in(enabled_operand_b),
        .out(b)
    );


    amd_axi_stream_converter_master  res_translator(
        .in(res),
        .out(result)
    );


    mul_sv mul_ip (
        .aclk(clock),
        .aresetn(reset),
        .S_AXIS_A(a),
        .S_AXIS_B(b),
        .M_AXIS_RESULT(res)
    );
`endif

endmodule