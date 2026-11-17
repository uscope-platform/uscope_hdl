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
`timescale 10 ns / 1 ns
`include "axi_lite_BFM.svh"

module enable_generator_param_ext_tb_tb();

    logic clk, rst;
    logic gen_en;
    logic ext_tb;
    wire [4:0] en_out;

    //clock generation
    initial clk = 1;
    always #0.5 clk = ~clk;

    // reset generation
    initial begin
        rst <= 1;
        #3 rst <= 0;
        #5 rst <= 1;
    end

    // external timebase: one-clock pulse every 4 clocks
    int tb_cnt = 0;
    always @(posedge clk) begin
        tb_cnt <= (tb_cnt == 3) ? 0 : tb_cnt + 1;
        ext_tb <= (tb_cnt == 3);
    end

    axi_lite axil();

    enable_generator_param #(
        .N_ENABLES(5),
        .EXTERNAL_TIMEBASE_ENABLE(1)
    ) gen (
        .clock(clk),
        .ext_timebase(ext_tb),
        .reset(rst),
        .gen_enable_in(gen_en),
        .pause(1'b0),
        .enable_out(en_out),
        .axil(axil)
    );

    localparam control_addr = 0;
    localparam period_addr = 4;
    localparam treshold_0_addr = 8;
    localparam treshold_1_addr = 12;
    localparam treshold_2_addr = 16;
    localparam treshold_3_addr = 20;
    localparam treshold_4_addr = 24;

    axi_lite_BFM axi_bfm;

    // ---------------- checkers ----------------
    logic pulse_check = 0;   // sync mode:   every output is a one-clock pulse
    logic bypass_check = 0;  // bypass mode: outputs follow ext_tb, one clock late
    logic ext_tb_d = 0;
    logic [4:0] en_prev = 0;
    int pulses_seen = 0;
    int errors = 0;

    always @(posedge clk) begin
        ext_tb_d <= ext_tb;
        en_prev  <= en_out;

        if (pulse_check) begin
            if (|(en_out & en_prev)) begin
                errors++;
                $error("output high for more than one clock: %b", en_out);
            end
            if (|(en_out & ~en_prev)) pulses_seen++;
        end

        if (bypass_check && en_out !== {5{ext_tb_d}}) begin
            errors++;
            $error("bypass mismatch: en_out=%b ext_tb_d=%b", en_out, ext_tb_d);
        end
    end

    // ---------------- stimulus ----------------
    initial begin
        axi_bfm = new(axil,1);
        gen_en = 0;
        #10 axi_bfm.write(period_addr, 16);
        #3 axi_bfm.write(treshold_0_addr,32'h4);
        #3 axi_bfm.write(treshold_1_addr,32'h5);
        #3 axi_bfm.write(treshold_2_addr,32'h6);
        #3 axi_bfm.write(treshold_3_addr,32'h7);
        #3 axi_bfm.write(treshold_4_addr,32'h9);
        #5 gen_en = 1;

        // sync mode: outputs must be one-clock pulses
        #10 pulse_check = 1;
        #1000 pulse_check = 0;
        if (pulses_seen == 0) begin
            errors++;
            $error("no enable pulses seen with period 16");
        end

        // period 1: bypass, outputs must follow ext_tb (one clock late)
        axi_bfm.write(period_addr, 1);
        #10 bypass_check = 1;
        #200 bypass_check = 0;

        // period 0: same as period 1
        axi_bfm.write(period_addr, 0);
        #10 bypass_check = 1;
        #200 bypass_check = 0;

        // back to sync mode with a longer period
        axi_bfm.write(period_addr, 32);
        pulses_seen = 0;
        #10 pulse_check = 1;
        #1000 pulse_check = 0;
        if (pulses_seen == 0) begin
            errors++;
            $error("no enable pulses seen with period 32");
        end

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

endmodule
