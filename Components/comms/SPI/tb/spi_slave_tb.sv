// Copyright 2025 Filippo Savi
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
    localparam MAX_SPI_DATA_WIDTH=32;

    reg [N_CHANNELS-1:0] mosi;
    reg sclk;
    reg [N_CHANNELS-1:0] ss;
    wire [N_CHANNELS-1:0] miso;

    //clock generation
    initial clk = 1;
    always #0.5 clk = ~clk;
    event reset_done;


    reg[2:0] test_config;
    reg [7:0] test_width = 16;


    covergroup spi_config_cg @(posedge clk);

    coverpoint test_config[0] { bins clock_idle[] = {0,1}; }
    coverpoint test_config[1] { bins latching_edge[] = {0,1}; }
    coverpoint test_config[2] { bins ss_polarity[] = {0,1}; } 

    // Cover width (8–16)
    coverpoint test_width {
        bins widths[] = {[4:32]};
    }

    cross test_config, test_width;

    endgroup : spi_config_cg

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

    reg [MAX_SPI_DATA_WIDTH-1:0] data_out [2:0];

    spi_config_cg spi_cov = new();

    SPI_slave #(
        .N_CHANNELS(3),
        .OUTPUT_WIDTH(MAX_SPI_DATA_WIDTH),
        .REGISTERS_WIDTH(MAX_SPI_DATA_WIDTH)
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

    reg [MAX_SPI_DATA_WIDTH-1:0] test_pattern;

    task static send_spi_pattern(
        input logic [MAX_SPI_DATA_WIDTH-1:0] pattern,
        input logic [7:0] transfer_length,
        input logic ss_polarity,
        input logic latching_edge,
        input logic clock_idle
    );
        #10 axil_bfm.write(4, transfer_length);
        #10 axil_bfm.write(0,{ss_polarity, latching_edge, clock_idle});
        #5 ss[0] = ss_polarity;
        #5 sclk = clock_idle;
        #5 ss[0] = ~ss_polarity;
        spi_cov.sample();
        for (int i = 0; i < transfer_length; i++) begin
            #1 mosi[0] = pattern[i];
            #10 sclk = ~clock_idle;
            #9 sclk = clock_idle;
        end
        #5 sclk = clock_idle;
        #5 ss[0] = ss_polarity;
    endtask

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

        #2 test_pattern = 16'hA5A5;
        send_spi_pattern( test_pattern, test_width, 0, 0, 0);
        #5;
        assert (data_out[0] == test_pattern)
        else begin
            $error("Data mismatch: expected %h, got %h", test_pattern, data_out[0]);
            $fatal;
        end
        #1000;

        // SS positive, data sampled on rising edge, clock idle high

        #2 test_pattern = 16'h5A5A;
        send_spi_pattern( test_pattern, test_width, 0, 0, 1);
        #5;
        assert (data_out[0] == test_pattern)
        else begin
            $error("Data mismatch: expected %h, got %h", test_pattern, data_out[0]);
            $fatal;
        end
        #1000;


        // SS positive, data sampled on falling edge, clock idle low

        #2 test_pattern = 16'hA5A5;
        send_spi_pattern( test_pattern, test_width, 0, 1, 0);
        #5;
        assert (data_out[0] == test_pattern)
        else begin
            $error("Data mismatch: expected %h, got %h", test_pattern, data_out[0]);
            $fatal;
        end
        #1000;

        // SS positive, data sampled on falling edge, clock idle high

        #2 test_pattern = 16'h5A5A;
        send_spi_pattern( test_pattern, test_width, 0, 1, 1);
        #5;
        assert (data_out[0] == test_pattern)
        else begin
            $error("Data mismatch: expected %h, got %h", test_pattern, data_out[0]);
            $fatal;
        end
        #1000;


        // SS negative, data sampled on rising edge, clock idle low

        #2 test_pattern = 16'hA5A5;
        send_spi_pattern( test_pattern, test_width, 1, 0, 0);
        #5;
        assert (data_out[0] == test_pattern)
        else begin
            $error("Data mismatch: expected %h, got %h", test_pattern, data_out[0]);
            $fatal;
        end
        #1000;

        // SS negative, data sampled on rising edge, clock idle high

        #2 test_pattern = 16'h5A5A;
        send_spi_pattern( test_pattern, test_width, 1, 0, 1);
        #5;
        assert (data_out[0] == test_pattern)
        else begin
            $error("Data mismatch: expected %h, got %h", test_pattern, data_out[0]);
            $fatal;
        end
        #1000;


        // SS negative, data sampled on falling edge, clock idle low

        #2 test_pattern = 16'hA5A5;
        send_spi_pattern( test_pattern, test_width, 1, 1, 0);
        #5;
        assert (data_out[0] == test_pattern)
        else begin
            $error("Data mismatch: expected %h, got %h", test_pattern, data_out[0]);
            $fatal;
        end
        #1000;

        // SS negative, data sampled on falling edge, clock idle high

        #2 test_pattern = 16'h5A5A;
        send_spi_pattern( test_pattern, test_width, 1, 1, 1);
        #5;
        assert (data_out[0] == test_pattern)
        else begin
            $error("Data mismatch: expected %h, got %h", test_pattern, data_out[0]);
            $fatal;
        end
        #1000;

        #30000;
        repeat(5000)begin
            test_width = $urandom_range(4,32);
            test_pattern = $urandom();
            test_pattern = test_pattern & ((1<<test_width)-1);
            test_config = $urandom_range(0,7);
            send_spi_pattern( test_pattern, test_width, test_config[2], test_config[1], test_config[0]);
            #5;
            assert (data_out[0] == test_pattern)
            else begin
                $error("Data mismatch: expected %h, got %h", test_pattern, data_out[0]);
                $fatal;
            end
            #500;
        end
        $finish;
    end



endmodule
