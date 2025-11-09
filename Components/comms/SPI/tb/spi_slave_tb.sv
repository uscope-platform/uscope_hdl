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
    localparam  msb_first = 1;

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
    reg [7:0] test_channel = 0;


    covergroup spi_config_cg @(posedge clk);

        coverpoint test_channel { 
            bins channels[] = {[0:2]}; 
        }

        coverpoint test_config[0] { bins clock_idle[] = {0,1}; }
        coverpoint test_config[1] { bins latching_edge[] = {0,1}; }
        coverpoint test_config[2] { bins ss_polarity[] = {0,1}; } 

        // Cover width (8–16)
        coverpoint test_width {
            bins widths[] = {[4:32]};
        }

        cross test_config, test_width, test_channel;

    endgroup : spi_config_cg

    // reset generation
    initial begin
        rst <=1;
        #3 rst<=0;
        #5 rst <=1;
        ->reset_done;
    end

    reg spi_sclk;
    initial begin
        spi_sclk = 0;
        forever begin
        #4.8 spi_sclk = 1;
        #5.4 spi_sclk = 0;
        end
    end

    axi_lite axil();
    axi_stream data_in();

    axi_lite_BFM axil_bfm;

    spi_config_cg spi_cov = new();

    axi_stream spi_data_out [N_CHANNELS]();
    axi_stream spi_data_in [N_CHANNELS]();

    SPI_slave #(
        .N_CHANNELS(N_CHANNELS),
        .OUTPUT_WIDTH(MAX_SPI_DATA_WIDTH),
        .REGISTERS_WIDTH(MAX_SPI_DATA_WIDTH)
    ) uut(
        .clock(clk),
        .reset(rst),
        .MISO(miso),
        .SCLK(sclk),
        .MOSI(mosi),
        .SS(ss),
        .enable(1),
        .axi_in(axil),
        .spi_data_in(spi_data_in),
        .spi_data_out(spi_data_out)
    );

    reg [MAX_SPI_DATA_WIDTH-1:0] reception_pattern;
    reg [MAX_SPI_DATA_WIDTH-1:0] transmission_pattern;
    reg enable_sclk = 0;
    reg default_clock = 0;
    reg [MAX_SPI_DATA_WIDTH-1:0] received_data = 0;

    task static send_spi_pattern(
        input logic [MAX_SPI_DATA_WIDTH-1:0] pattern,
        input logic [7:0] transfer_length,
        input logic [7:0] channel,
        input logic ss_polarity,
        input logic latching_edge,
        input logic clock_idle
    );
        default_clock = clock_idle;
        #10 axil_bfm.write(4, transfer_length);
        #10 axil_bfm.write(0,{msb_first, ss_polarity, latching_edge, clock_idle});

        #5 ss[channel] = ss_polarity;
        if(clock_idle == 0)begin
            @(negedge spi_sclk);
        end else begin
            @(posedge spi_sclk);
            sclk = 1;
        end
        #0.1 ss[channel] = ~ss_polarity;
        mosi[channel] = pattern[transfer_length-1];

        enable_sclk = 1;
        
        spi_cov.sample();
        for (int i = 0; i < transfer_length; i++) begin
            if(latching_edge  == 0)begin
                @(posedge spi_sclk) received_data[transfer_length-1-i] = miso[channel];
                @(negedge spi_sclk) if(i <transfer_length-1) mosi[channel] = pattern[transfer_length-2-i];
            end else begin
                @(negedge spi_sclk) mosi[channel] = pattern[transfer_length-1-i];
                @(posedge spi_sclk) received_data[transfer_length-1-i] = miso[channel];
            end
        end
        #0.1 ss[channel] = ss_polarity;
        enable_sclk = 0;
        default_clock = clock_idle;
    endtask


    always_comb begin
        if(enable_sclk == 1)
            sclk = spi_sclk;
        else
            sclk = default_clock;
    end
    

    task static check_test(
        input logic [MAX_SPI_DATA_WIDTH-1:0] tx_pattern,
        input logic [MAX_SPI_DATA_WIDTH-1:0] rx_pattern,
        input logic [7:0] transfer_length, 
        input logic [7:0] channel
    );

    reg [MAX_SPI_DATA_WIDTH-1:0] tx;
    reg [MAX_SPI_DATA_WIDTH-1:0] rx;
    tx = tx_pattern&((1<<transfer_length)-1);
    rx = rx_pattern&((1<<transfer_length)-1);
    case (channel)
        0: begin
            wait (spi_data_out[0].valid == 1);
            assert (spi_data_out[0].data == tx)
            else begin
                $error("TRASMITTED DATA mismatch: expected %h, got %h", tx, spi_data_out[0].data);
                $fatal;
            end
        end
        1: begin
            wait (spi_data_out[1].valid == 1);
            assert (spi_data_out[1].data == tx)
            else begin
                $error("TRASMITTED DATA mismatch: expected %h, got %h", tx, spi_data_out[1].data);
                $fatal;
            end
        end
        2: begin
            wait (spi_data_out[2].valid == 1);
            assert (spi_data_out[2].data == tx)
            else begin
                $error("TRASMITTED DATA mismatch: expected %h, got %h", tx, spi_data_out[2].data);
                $fatal;
            end
        end
     endcase
    assert (received_data == rx)
    else begin
        $error("RECEIVED DATA mismatch: expected %h, got %h", rx, received_data);
        $fatal;
    end
    received_data = 0;
    endtask

    task static setup_slave_data(
        input logic [MAX_SPI_DATA_WIDTH-1:0] pattern,
        input logic [7:0] channel
    );
     case (channel)
        0: begin
            spi_data_in[0].data = pattern;
            spi_data_in[0].valid = 1;
            #1 spi_data_in[0].valid = 0;
            spi_data_in[0].data = 0;
        end
        1: begin
            spi_data_in[1].data = pattern;
            spi_data_in[1].valid = 1;
            #1 spi_data_in[1].valid = 0;
            spi_data_in[1].data = 0;
        end
        2: begin
            spi_data_in[2].data = pattern;
            spi_data_in[2].valid = 1;
            #1 spi_data_in[2].valid = 0;
            spi_data_in[2].data = 0;
        end
     endcase

    endtask

    initial begin

        mosi <= 0;
        ss <= 0;
        sclk <= 0;
        test_config <= 0;

        axil_bfm = new(axil, 1);
        @(reset_done);


        #10 axil_bfm.write(0,4'b1000);
        #10 axil_bfm.write(4,16);
        $display("--------------------------------------------------------");
        $display("     DIRECTED TESTING");
        $display("--------------------------------------------------------");


        // SS positive, data sampled on rising edge, clock idle low

        #2 reception_pattern = 16'hCAFE;
        #5 transmission_pattern = 16'hBEBE;
        setup_slave_data(transmission_pattern, test_channel);
        send_spi_pattern(reception_pattern, test_width, test_channel, 1, 0, 0);
        check_test(reception_pattern, transmission_pattern, test_width, test_channel);
        #1000;

        // SS positive, data sampled on rising edge, clock idle high

        #2 reception_pattern = 16'h5A5A;
        #5 transmission_pattern =  16'hC3C3;
        setup_slave_data(transmission_pattern, test_channel);
        send_spi_pattern( reception_pattern, test_width, test_channel, 0, 0, 1);
        check_test(reception_pattern, transmission_pattern, test_width, test_channel);
        #1000;


        // SS positive, data sampled on falling edge, clock idle low

        #2 reception_pattern = 16'hA5A5;
        #5 transmission_pattern = 16'h3C3C;
        setup_slave_data(transmission_pattern, test_channel);
        send_spi_pattern( reception_pattern, test_width, test_channel, 0, 1, 0);
        check_test(reception_pattern, transmission_pattern, test_width, test_channel);
        #1000;

        // SS positive, data sampled on falling edge, clock idle high

        #2 reception_pattern = 16'h5A5A;
        #5 transmission_pattern =  16'hC3C3;
        setup_slave_data(transmission_pattern, test_channel);
        send_spi_pattern( reception_pattern, test_width, test_channel, 0, 1, 1);
        check_test(reception_pattern, transmission_pattern, test_width, test_channel);
        #1000;


        // SS negative, data sampled on rising edge, clock idle low

        #2 reception_pattern = 16'hA5A5;
        #5 transmission_pattern = 16'h3C3C;
        setup_slave_data(transmission_pattern, test_channel);
        send_spi_pattern( reception_pattern, test_width, test_channel, 1, 0, 0);
        check_test(reception_pattern, transmission_pattern, test_width, test_channel);
        #1000;

        // SS negative, data sampled on rising edge, clock idle high

        #2 reception_pattern = 16'h5A5A;
        #5 transmission_pattern =  16'hC3C3;
        setup_slave_data(transmission_pattern, test_channel);
        send_spi_pattern( reception_pattern, test_width, test_channel, 1, 0, 1);
        check_test(reception_pattern, transmission_pattern,  test_width, test_channel);
        #1000;


        // SS negative, data sampled on falling edge, clock idle low

        #2 reception_pattern = 16'hA5A5;
        #5 transmission_pattern = 16'h3C3C;
        setup_slave_data(transmission_pattern, test_channel);
        send_spi_pattern( reception_pattern, test_width, test_channel, 1, 1, 0);
        check_test(reception_pattern, transmission_pattern, test_width, test_channel);
        #1000;

        // SS negative, data sampled on falling edge, clock idle high

        #2 reception_pattern = 16'h5A5A;
        #5 transmission_pattern =  16'hC3C3;
        setup_slave_data(transmission_pattern, test_channel);
        send_spi_pattern( reception_pattern, test_width, test_channel, 1, 1, 1);
        check_test(reception_pattern, transmission_pattern, test_width, test_channel);
        #1000;

            #5000;
            repeat(9000)begin
                test_width = $urandom_range(4,32);
                reception_pattern = $urandom() & ((1<<test_width)-1);
                test_config = $urandom_range(0,7);
                test_channel = $urandom_range(0,N_CHANNELS-1);
                transmission_pattern = $urandom() & ((1<<test_width)-1);
                setup_slave_data(transmission_pattern, test_channel);
                send_spi_pattern(reception_pattern, test_width, test_channel, test_config[2], test_config[1], test_config[0]);
                check_test(reception_pattern, transmission_pattern, test_width, test_channel);
                #500;
            end
            $finish;

        

    end



endmodule
