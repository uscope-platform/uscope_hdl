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

module fcore_adder_ip (
    input wire clock,
    input wire reset,
    input wire enable,
    axi_stream.slave operand_a,
    axi_stream.slave operand_b,
    axi_stream.slave operation,
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


    axi_stream enabled_operation();
    assign enabled_operation.valid = operation.valid & enable;
    assign enabled_operation.data = operation.data;
    assign enabled_operation.dest = operation.dest;
    assign enabled_operation.user = operation.user;
    assign enabled_operation.tlast = operation.tlast;
    assign operation.ready = enabled_operation.ready & enable;



    vivado_axis_v1_0 a();
    vivado_axis_v1_0 b();
    vivado_axis_v1_0 op();
    vivado_axis_v1_0 res();



    amd_axi_stream_converter_slave  a_translator(
        .in(enabled_operand_a),
        .out(a)
    );

    amd_axi_stream_converter_slave  b_translator(
        .in(enabled_operand_b),
        .out(b)
    );

    amd_axi_stream_converter_slave  op_translator(
        .in(enabled_operation),
        .out(op)
    );

    amd_axi_stream_converter_master  res_translator(
        .in(res),
        .out(result)
    );




    fast_adder_sv adder_ip (
        .aclk(clock),
        .aresetn(reset),
        .S_AXIS_A(a),
        .S_AXIS_B(b),
        .S_AXIS_OPERATION(op),
        .M_AXIS_RESULT(res)
    );


endmodule