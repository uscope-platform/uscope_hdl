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
`include "SimpleBus_BFM.svh"
`include "SPI_BFM.svh"

module MC_spi_bfm_tb();
    
    logic clk, rst;

    event master_task_start;
    event slave_task_start;
    event transaction_check;

    parameter spi_width = 12;
    
    logic [2:0] mosi;
    logic [2:0] miso;
    wire  sclk, ss, out_val;
    logic [31:0] out[2:0];

    reg [31:0] SPI_write_data;
    reg SPI_write_valid;

    Simplebus s();
    SPI_if spi_if_1();
    SPI_if spi_if_2();
    SPI_if spi_if_3();

    assign spi_if_1.SS = ss;
    assign spi_if_1.SCLK = sclk;
    assign spi_if_1.MOSI = mosi[0];
    assign miso[0] = spi_if_1.MISO;


    assign spi_if_2.SS = ss;
    assign spi_if_2.SCLK = sclk;
    assign spi_if_2.MOSI = mosi[1];
    assign miso[1] = spi_if_2.MISO;


    assign spi_if_3.SS = ss;
    assign spi_if_3.SCLK = sclk;
    assign spi_if_3.MOSI = mosi[2];
    assign miso[2] = spi_if_3.MISO;

    //clock generation
    initial clk = 1; 
    always #0.5 clk = ~clk; 

    
    // reset generation
    initial begin
        rst <=1;
        #3 rst<=0;
        #5 rst <=1;
    end

    
    defparam DUT.N_CHANNELS = 3;
    SPI DUT(
        .clock(clk),
        .reset(rst),
        .data_valid(out_val),
        .data_out(out),
        .MISO(miso),
        .SCLK(sclk),
        .MOSI(mosi),
        .SS(ss),
        .simple_bus(s),
        .SPI_write_data(SPI_write_data),
        .SPI_write_valid(SPI_write_valid)
    );

    simplebus_BFM BFM;
    SPI_BFM spi_bfm_1;
    SPI_BFM spi_bfm_2;
    SPI_BFM spi_bfm_3;

    initial begin
        //INITIAL SETTINGS AND INSTANTIATIONS OF CLASSES
        BFM = new(s,1);
        spi_bfm_1 = new(spi_if_1,1);
        spi_bfm_2 = new(spi_if_2,1);
        spi_bfm_3 = new(spi_if_3,1);
        SPI_write_valid <= 0;
        SPI_write_data <= 0;

        //TEST MASTER MODE
        #10 -> slave_task_start;
        #2 -> master_task_start;
    end
    

    logic [spi_width-1:0] slave_data_s1 = 0;
    logic [spi_width-1:0] slave_data_e1 = 0;
    logic [spi_width-1:0] slave_data_r1 = 0;
    logic [spi_width-1:0] master_data_s1 =0;
    logic [spi_width-1:0] master_data_e1 =0;
    logic [spi_width-1:0] master_data_r1 =0;
    
    logic [spi_width-1:0] slave_data_s2 = 0;
    logic [spi_width-1:0] slave_data_e2 = 0;
    logic [spi_width-1:0] slave_data_r2 = 0;
    logic [spi_width-1:0] master_data_s2 =0;
    logic [spi_width-1:0] master_data_e2 =0;
    logic [spi_width-1:0] master_data_r2 =0;

    logic [spi_width-1:0] slave_data_s3 = 0;
    logic [spi_width-1:0] slave_data_e3 = 0;
    logic [spi_width-1:0] slave_data_r3 = 0;
    logic [spi_width-1:0] master_data_s3 =0;
    logic [spi_width-1:0] master_data_e3 =0;
    logic [spi_width-1:0] master_data_r3 =0;


    initial begin : slave_1
        @(slave_task_start);
        forever begin
            slave_data_s1 = $urandom;
            spi_bfm_1.transfer(slave_data_s1, spi_width,master_data_r1);
            slave_data_e1 = slave_data_s1;
        end
    end


    initial begin : slave_2
        @(slave_task_start);
        forever begin
            slave_data_s2 = $urandom;
            spi_bfm_2.transfer(slave_data_s2, spi_width,master_data_r2);
            slave_data_e2 = slave_data_s2;
        end
    end

    initial begin : slave_3
        @(slave_task_start);
        forever begin
            slave_data_s3 = $urandom;
            spi_bfm_3.transfer(slave_data_s3, spi_width,master_data_r3);
            slave_data_e3 = slave_data_s3;
        end
    end

    initial begin : master_1
        @(master_task_start);
            #10 BFM.write(32'h43C00000,31'h131c2);
            #5 BFM.write(32'h43C00004,31'h1b);
            
        forever begin
            #5 master_data_s1 = $urandom;
            master_data_s2 = $urandom;
            master_data_s3 = $urandom;
            BFM.write(32'h43C00008,master_data_s1);
            BFM.write(32'h43C00018,master_data_s2);
            BFM.write(32'h43C0001C,master_data_s3);
            #5 BFM.write(32'h43C0000C,31'h0);
            BFM.read(32'h43C00010,slave_data_r1);
            master_data_e1 <= master_data_s1;
            BFM.read(32'h43C00020,slave_data_r2);
            master_data_e2 <= master_data_s2;
            BFM.read(32'h43C00024,slave_data_r3);
            master_data_e3 <= master_data_s3;
            #3->transaction_check;
        end
    end

    initial begin: test_checker_1
        @(transaction_check);
        #1;
        //SLAVE 1
        assert (slave_data_e1[11:0] == slave_data_r1[11:0]) 
        else begin
            $display("MOSI 1 SIDE ERROR: expected value %h | recived value %h", slave_data_e1[11:0], slave_data_r1[11:0]);
            $stop();
        end
        assert (master_data_e1[11:0] == master_data_r1[11:0]) 
        else begin
            $display("MISO 1 SIDE ERROR: expected value %h | recived value %h", master_data_e1[11:0], master_data_r1[11:0]);
            $stop();
        end
        //SLAVE 2
        assert (slave_data_e2[11:0] == slave_data_r2[11:0]) 
        else begin
            $display("MOSI 2 SIDE ERROR: expected value %h | recived value %h", slave_data_e2[11:0], slave_data_r2[11:0]);
            $stop();
        end
        assert (master_data_e2[11:0] == master_data_r2[11:0]) 
        else begin
            $display("MISO 2 SIDE ERROR: expected value %h | recived value %h", master_data_e2[11:0], master_data_r2[11:0]);
            $stop();
        end
        //SLAVE 3
        assert (slave_data_e3[11:0] == slave_data_r3[11:0]) 
        else begin
            $display("MOSI 3 SIDE ERROR: expected value %h | recived value %h", slave_data_e3[11:0], slave_data_r3[11:0]);
            $stop();
        end
        assert (master_data_e3[11:0] == master_data_r3[11:0]) 
        else begin
            $display("MISO 3 SIDE ERROR: expected value %h | recived value %h", master_data_e3[11:0], master_data_r3[11:0]);
            $stop();
        end
        #1;
    end

endmodule