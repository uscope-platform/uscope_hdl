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

module hysteresis_controller_tb();
    reg  clk, reset, signed_out, unsigned_out;

    axi_lite unsigned_control();
    axi_lite signed_control();

    axi_stream in();


    //clock generation
    always begin
     clk = 1'b1;
     #0.5 clk = 1'b0;
     #0.5;
    end

    hysteresis_controller #(
        .SIGNED_INPUT("FALSE")
    ) unsigned_uut(
        .clock(clk),
        .reset(reset),
        .enable(1'b1),
        .in(in),
        .control_out(unsigned_out),
        .axi_in(unsigned_control)
    );

    hysteresis_controller #(
        .SIGNED_INPUT("TRUE")
    ) signed_uut(
        .clock(clk),
        .reset(reset),
        .enable(1'b1),
        .in(in),
        .control_out(signed_out),
        .axi_in(signed_control)
    );

    event config_done, reset_done;

    initial begin
        signed_control.initialize_master();
        unsigned_control.initialize_master();
        in.initialize();
        //Initial status
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;

        ->reset_done;
    end


    initial begin
        @(reset_done)
        #5 signed_control.write(32'h0, -30);
        #5 signed_control.write(32'h4, 30);

        #5 unsigned_control.write(32'h0, 0);
        #5 unsigned_control.write(32'h4, 43);
        ->config_done;
    end


    initial begin
        @(config_done);
        forever begin
            in.write($urandom_range(0, 100) - 50);
            #10;
        end
    end
endmodule