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

module fcore_itf_ip (
    input wire clock,
    input wire reset,
    input wire enable,
    axi_stream.slave operand_a,
    axi_stream.master result 
);


    axi_stream enabled_operand_a();
    assign enabled_operand_a.valid = operand_a.valid & enable;
    assign enabled_operand_a.data = operand_a.data;
    assign enabled_operand_a.dest = operand_a.dest;
    assign enabled_operand_a.user = operand_a.user;
    assign enabled_operand_a.tlast = operand_a.tlast;
    assign operand_a.ready = enabled_operand_a.ready & enable;


`ifdef VERILATOR
    // Model of the Xilinx floating point IP for Verilator, which can not run it. The operand is a signed 32 bit integer.
    // It is converted to double with the real system functions, which is exact, and narrowed to float with fp_fp64_to_fp32,
    // which rounds to nearest even. The latency is the one of the IP: 1 + 2 = 3 cycles.
    // As in the IP, the result carries the user of the operand, its dest and tlast are 0 and nothing is held back:
    // result.ready is not used. As in the generated wrapper, the ready of the input is 0.

    assign enabled_operand_a.ready = 1'b0;

    axi_stream #(.DATA_WIDTH(64)) wide();

    reg        wide_valid = 0;
    reg [63:0] wide_data;
    reg [31:0] wide_user;

    always_ff @(posedge clock) begin
        if (~reset) begin
            wide_valid <= 0;
        end else begin
            wide_valid <= enabled_operand_a.valid;
            wide_data <= $realtobits($itor($signed(enabled_operand_a.data)));
            wide_user <= enabled_operand_a.user;
        end
    end

    assign wide.valid = wide_valid;
    assign wide.data = wide_data;
    assign wide.user = wide_user;
    assign wide.dest = 0;
    assign wide.tlast = 1'b0;

    fp_fp64_to_fp32 narrow (
        .clock(clock),
        .reset(reset),
        .in(wide),
        .out(result)
    );
`else
    vivado_axis_v1_0 #( .TDATA_NUM_BYTES(4), .TDEST_WIDTH(32), .TUSER_WIDTH(32)) a();
    vivado_axis_v1_0 #( .TDATA_NUM_BYTES(4), .TDEST_WIDTH(32), .TUSER_WIDTH(32)) res();



    amd_axi_stream_converter_slave  a_translator(
        .in(enabled_operand_a),
        .out(a)
    );


    amd_axi_stream_converter_master  res_translator(
        .in(res),
        .out(result)
    );


    itf_sv itf_ip (
        .aclk(clock),
        .aresetn(reset),
        .S_AXIS_A(a),
        .M_AXIS_RESULT(res)
    );
`endif

endmodule