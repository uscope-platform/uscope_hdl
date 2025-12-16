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

`timescale 10ns / 1ns

module alu_results_combiner #(
    REGISTERED = 0
) (
    input wire clock,
    input wire reset,
    axi_stream.slave add_result,
    axi_stream.slave mul_result,
    axi_stream.slave rec_result,
    axi_stream.slave fti_result,
    axi_stream.slave itf_result,
    axi_stream.slave sat_result,
    axi_stream.slave logic_result,
    axi_stream.slave comparison_result,
    axi_stream.slave load_result,
    axi_stream.slave bitmanip_result,
    axi_stream.slave abs_result,
    axi_stream.slave csel_result,
    axi_stream.master result
);
    generate
        if(REGISTERED) begin
            always_ff@(posedge clock) begin
                result.valid <= 0;
                result.user <= 0;
                result.data <= 0;
                if(add_result.valid) begin
                    result.valid <= add_result.valid;
                    result.user <= 0;
                    result.data <= add_result.data;
                    result.dest <= add_result.user;
                end else if (mul_result.valid) begin
                    result.valid <= mul_result.valid;
                    result.user <= 0;
                    result.data <= mul_result.data;
                    result.dest <= mul_result.user;
                end else if (rec_result.valid) begin
                    result.valid <= rec_result.valid;
                    result.user <= 0;
                    result.data <= rec_result.data;
                    result.dest <= rec_result.user;
                end else if (fti_result.valid) begin
                    result.valid <= fti_result.valid;
                    result.user <= 0;
                    result.data <= fti_result.data;
                    result.dest <= fti_result.user;
                end else if (itf_result.valid) begin
                    result.valid <= itf_result.valid;
                    result.user <= 0;
                    result.data <= itf_result.data;
                    result.dest <= itf_result.user;
                end else if (sat_result.valid) begin
                    result.valid <= sat_result.valid;
                    result.user <= 0;
                    result.data <= sat_result.data;
                    result.dest <= sat_result.user;
                end else if (logic_result.valid) begin
                    result.valid <= logic_result.valid;
                    result.user <= 0;
                    result.data <= logic_result.data;
                    result.dest <= logic_result.user;
                end else if (comparison_result.valid) begin
                    result.valid <= comparison_result.valid;
                    result.user <= 0;
                    result.data <= comparison_result.data;
                    result.dest <= comparison_result.user;
                end else if (load_result.valid) begin
                    result.valid <= load_result.valid;
                    result.user <= 0;
                    result.data <= load_result.data;
                    result.dest <= load_result.dest;
                end else if (bitmanip_result.valid) begin
                    result.valid <= bitmanip_result.valid;
                    result.user <= 0;
                    result.data <= bitmanip_result.data;
                    result.dest <= bitmanip_result.user;
                end else if (abs_result.valid) begin
                    result.valid <= abs_result.valid;
                    result.user <= 0;
                    result.data <= abs_result.data;
                    result.dest <= abs_result.user;
                end else if (csel_result.valid) begin
                    result.valid <= csel_result.valid;
                    result.user <= 0;
                    result.data <= csel_result.data;
                    result.dest <= csel_result.user;
                end
            end

        end else begin
            always_comb begin
                if(add_result.valid) begin
                    result.valid <= add_result.valid;
                    result.user <= 0;
                    result.data <= add_result.data;
                    result.dest <= add_result.user;
                end else if (mul_result.valid) begin
                    result.valid <= mul_result.valid;
                    result.user <= 0;
                    result.data <= mul_result.data;
                    result.dest <= mul_result.user;
                end else if (rec_result.valid) begin
                    result.valid <= rec_result.valid;
                    result.user <= 0;
                    result.data <= rec_result.data;
                    result.dest <= rec_result.user;
                end else if (fti_result.valid) begin
                    result.valid <= fti_result.valid;
                    result.user <= 0;
                    result.data <= fti_result.data;
                    result.dest <= fti_result.user;
                end else if (itf_result.valid) begin
                    result.valid <= itf_result.valid;
                    result.user <= 0;
                    result.data <= itf_result.data;
                    result.dest <= itf_result.user;
                end else if (sat_result.valid) begin
                    result.valid <= sat_result.valid;
                    result.user <= 0;
                    result.data <= sat_result.data;
                    result.dest <= sat_result.user;
                end else if (logic_result.valid) begin
                    result.valid <= logic_result.valid;
                    result.user <= 0;
                    result.data <= logic_result.data;
                    result.dest <= logic_result.user;
                end else if (comparison_result.valid) begin
                    result.valid <= comparison_result.valid;
                    result.user <= 0;
                    result.data <= comparison_result.data;
                    result.dest <= comparison_result.user;
                end else if (load_result.valid) begin
                    result.valid <= load_result.valid;
                    result.user <= 0;
                    result.data <= load_result.data;
                    result.dest <= load_result.dest;
                end else if (bitmanip_result.valid) begin
                    result.valid <= bitmanip_result.valid;
                    result.user <= 0;
                    result.data <= bitmanip_result.data;
                    result.dest <= bitmanip_result.user;
                end else if (abs_result.valid) begin
                    result.valid <= abs_result.valid;
                    result.user <= 0;
                    result.data <= abs_result.data;
                    result.dest <= abs_result.user;
                end else if (csel_result.valid) begin
                    result.valid <= csel_result.valid;
                    result.user <= 0;
                    result.data <= csel_result.data;
                    result.dest <= csel_result.user;
                end else begin
                    result.valid <= 0;
                    result.user <= 0;
                    result.data <= 0;
                    result.dest <= 0;
                end
            end
        end
    endgenerate

    // Assert that no two valid signals are high at the same time

    wire [11:0] valid_vec;

    assign valid_vec = {
        add_result.valid,
        mul_result.valid,
        rec_result.valid,
        fti_result.valid,
        itf_result.valid,
        sat_result.valid,
        logic_result.valid,
        comparison_result.valid,
        load_result.valid,
        bitmanip_result.valid,
        abs_result.valid,
        csel_result.valid
    };

    assert_no_valid_collision: assert property (
        @(posedge clock)
        disable iff (!reset)
        $onehot0(valid_vec)
    ) else begin
        $display("---------------------------------------------------------------------------------------------------------");
        $display( "ALU result collision: multiple valid signals asserted: %b", valid_vec);

            if (add_result.valid)        $display("  --> add_result        user=0x%0h", add_result.user);
            if (mul_result.valid)        $display("  --> mul_result        user=0x%0h", mul_result.user);
            if (rec_result.valid)        $display("  --> rec_result        user=0x%0h", rec_result.user);
            if (fti_result.valid)        $display("  --> fti_result        user=0x%0h", fti_result.user);
            if (itf_result.valid)        $display("  --> itf_result        user=0x%0h", itf_result.user);
            if (sat_result.valid)        $display("  --> sat_result        user=0x%0h", sat_result.user);
            if (logic_result.valid)      $display("  --> logic_result      user=0x%0h", logic_result.user);
            if (comparison_result.valid) $display("  --> comparison_result user=0x%0h", comparison_result.user);
            if (load_result.valid)       $display("  --> load_result       user=0x%0h", load_result.user);
            if (bitmanip_result.valid)   $display("  --> bitmanip_result   user=0x%0h", bitmanip_result.user);
            if (abs_result.valid)        $display("  --> abs_result        user=0x%0h", abs_result.user);
            if (csel_result.valid)       $display("  --> csel_result       user=0x%0h", csel_result.user);
        $display("---------------------------------------------------------------------------------------------------------");
    end


endmodule
