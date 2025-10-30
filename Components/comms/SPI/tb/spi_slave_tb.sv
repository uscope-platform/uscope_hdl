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

module spi_slave_tb();

    logic clk, rst;

    localparam N_CHANNELS=3;

    reg [N_CHANNELS-1:0] mosi;
    reg sclk;
    reg [N_CHANNELS-1:0] ss;
    wire [N_CHANNELS-1:0] miso;

    //clock generation
    initial clk = 1;
    always #0.5 clk = ~clk;
    event reset_done;


    // reset generation
    initial begin
        rst <=1;
        #3 rst<=0;
        #5 rst <=1;
        ->reset_done;
    end

    axi_lite axil();
    axi_stream data_in();

    axi_lite_BFM axil_bfm;

    reg [15:0] data_out [2:0];

    SPI_slave #(
        .N_CHANNELS(3),
        .OUTPUT_WIDTH(16)
    ) uut(
        .clock(clk),
        .reset(rst),
        .data_valid(),
        .data_out(data_out),
        .MISO(miso),
        .SCLK(sclk),
        .MOSI(mosi),
        .SS(ss),
        .axi_in(axil),
        .external_spi_transfer(data_in)
    );

    reg [15:0] test_pattern;

    task static send_spi_pattern(
        input logic [15:0] pattern,
        input logic ss_polarity,
        input logic clock_idle
    );
        #5 sclk = clock_idle;
        #5 ss[0] = ~ss_polarity;
        for (int i = 0; i < 16; i++) begin
            #1 mosi[0] = pattern[i];
            #10 sclk = ~clock_idle;
            #9 sclk = clock_idle;
        end
        #5 sclk = clock_idle;
        #5 ss[0] = ss_polarity;
    endtask

    reg[2:0] signal_config;

    initial begin

        mosi <= 0;
        ss <= 0;
        sclk <= 0;

        axil_bfm = new(axil, 1);
        @(reset_done);

        $display("--------------------------------------------------------");
        $display("     DIRECTED TESTING");
        $display("--------------------------------------------------------");

        // SS positive, data sampled on rising edge, clock idle low

        #10 axil_bfm.write(4, 16);
        #10 axil_bfm.write(0, 3'b000);
        #2 test_pattern = 16'hA5A5;
        send_spi_pattern( test_pattern, 0, 0);
        #5;
        assert (data_out[0] == test_pattern)
        else begin
            $error("Data mismatch: expected %h, got %h", test_pattern, data_out[0]);
            $fatal;
        end
        #1000;

        // SS positive, data sampled on rising edge, clock idle high

        #10 axil_bfm.write(0, 3'b001);
        #2 test_pattern = 16'h5A5A;
        send_spi_pattern( test_pattern, 0, 1);
        #5;
        assert (data_out[0] == test_pattern)
        else begin
            $error("Data mismatch: expected %h, got %h", test_pattern, data_out[0]);
            $fatal;
        end
        #1000;


        // SS positive, data sampled on falling edge, clock idle low

        #10 axil_bfm.write(0, 3'b010);
        #2 test_pattern = 16'hA5A5;
        send_spi_pattern( test_pattern, 0, 0);
        #5;
        assert (data_out[0] == test_pattern)
        else begin
            $error("Data mismatch: expected %h, got %h", test_pattern, data_out[0]);
            $fatal;
        end
        #1000;

        // SS positive, data sampled on falling edge, clock idle high

        #10 axil_bfm.write(0, 3'b011);
        #2 test_pattern = 16'h5A5A;
        send_spi_pattern( test_pattern, 0, 1);
        #5;
        assert (data_out[0] == test_pattern)
        else begin
            $error("Data mismatch: expected %h, got %h", test_pattern, data_out[0]);
            $fatal;
        end
        #1000;


        // SS negative, data sampled on rising edge, clock idle low

        #10 axil_bfm.write(0, 3'b100);
        #5 ss[0] = 1'b1;
        #2 test_pattern = 16'hA5A5;
        send_spi_pattern( test_pattern, 1, 0);
        #5;
        assert (data_out[0] == test_pattern)
        else begin
            $error("Data mismatch: expected %h, got %h", test_pattern, data_out[0]);
            $fatal;
        end
        #1000;

        // SS negative, data sampled on rising edge, clock idle high

        #10 axil_bfm.write(0, 3'b101);
        #2 test_pattern = 16'h5A5A;
        send_spi_pattern( test_pattern, 1, 1);
        #5;
        assert (data_out[0] == test_pattern)
        else begin
            $error("Data mismatch: expected %h, got %h", test_pattern, data_out[0]);
            $fatal;
        end
        #1000;


        // SS negative, data sampled on falling edge, clock idle low

        #10 axil_bfm.write(0, 3'b110);
        #2 test_pattern = 16'hA5A5;
        send_spi_pattern( test_pattern, 1, 0);
        #5;
        assert (data_out[0] == test_pattern)
        else begin
            $error("Data mismatch: expected %h, got %h", test_pattern, data_out[0]);
            $fatal;
        end
        #1000;

        // SS negative, data sampled on falling edge, clock idle high

        #10 axil_bfm.write(0, 3'b111);
        #2 test_pattern = 16'h5A5A;
        send_spi_pattern( test_pattern, 1, 0);
        #5;
        assert (data_out[0] == test_pattern)
        else begin
            $error("Data mismatch: expected %h, got %h", test_pattern, data_out[0]);
            $fatal;
        end
        #1000;

        #30000;

    end

endmodule
