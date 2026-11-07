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

module fcore_fti_ip (
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
    // Model of the Xilinx floating point IP for Verilator, which can not run it. The operand is widened to double with
    // fp_fp32_to_fp64 and converted to a signed 32 bit integer with the real system functions, which truncate towards
    // zero. The latency is the one of the IP: 2 + 1 = 3 cycles.
    // A value outside the range of the integer saturates and a NaN gives 0, which is an assumption: the emulator does not
    // define these cases.
    // As in the IP, the result carries the user of the operand, its dest and tlast are 0 and nothing is held back:
    // result.ready is not used. As in the generated wrapper, the ready of the input is 0.

    assign enabled_operand_a.ready = 1'b0;

    axi_stream #(.DATA_WIDTH(32)) narrow_a();
    axi_stream #(.DATA_WIDTH(64)) wide_a();

    assign narrow_a.valid = enabled_operand_a.valid;
    assign narrow_a.data = enabled_operand_a.data;
    assign narrow_a.user = enabled_operand_a.user;
    assign narrow_a.dest = 0;
    assign narrow_a.tlast = 1'b0;

    assign wide_a.ready = 1'b1;

    fp_fp32_to_fp64 widen_a (
        .clock(clock),
        .reset(reset),
        .in(narrow_a),
        .out(wide_a)
    );

    // the conversion of a value that is outside of the range of an integer is not defined for $rtoi, so it is done here
    function automatic logic [31:0] to_integer (input logic [63:0] bits);
        real value;
        value = $bitstoreal(bits);
        if (bits[62:52] == 11'h7FF && bits[51:0] != 0) begin
            to_integer = 32'h00000000;
        end else if (value >= 2147483648.0) begin
            to_integer = 32'h7FFFFFFF;
        end else if (value <= -2147483649.0) begin
            to_integer = 32'h80000000;
        end else begin
            to_integer = 32'($rtoi(value));
        end
    endfunction

    reg        integer_valid = 0;
    reg [31:0] integer_data;
    reg [31:0] integer_user;

    always_ff @(posedge clock) begin
        if (~reset) begin
            integer_valid <= 0;
        end else begin
            integer_valid <= wide_a.valid;
            integer_data <= to_integer(wide_a.data);
            integer_user <= wide_a.user;
        end
    end

    assign result.valid = integer_valid;
    assign result.data = integer_data;
    assign result.user = integer_user;
    assign result.dest = 0;
    assign result.tlast = 1'b0;
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


    fti_sv fti_ip (
        .aclk(clock),
        .aresetn(reset),
        .S_AXIS_A(a),
        .M_AXIS_RESULT(res)
    );
`endif

endmodule