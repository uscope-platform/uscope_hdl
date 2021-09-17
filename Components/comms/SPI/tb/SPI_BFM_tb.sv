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

module SPI_bfm_tb();
    
    logic clk, rst;

    event master_task_start;
    event slave_task_start;
    event transaction_check;

    parameter spi_width = 12;

    logic mosi, sclk,sclk_en;
    logic spi_mode,out_val;
    wire sclk_in;
    wire ss;
    wire ss_in;
    logic sclk_slave;
    logic ss_slave;
    wire miso;
    logic [31:0] out[0:0];

    reg [31:0] SPI_write_data;
    reg SPI_write_valid;

    parameter spi_mode_master = 0, spi_mode_slave = 1;

    assign sclk_in = spi_mode ? sclk_slave & sclk_en : 1'bz;
    assign sclk = !spi_mode ? sclk_in : 1'b0;
    assign ss_in = spi_mode ? ss_slave : 1'bz;
    assign ss = !spi_mode ? ss_in : 1'b0;

    assign spi_if.SS = ss;
    assign spi_if.SCLK = sclk;
    assign spi_if.MOSI = mosi;
    assign miso = spi_if.MISO;

    //clock generation
    initial clk = 1; 
    always #0.5 clk = ~clk; 
    

    initial #0.5 sclk_slave = 1;
    always #1 sclk_slave = ~sclk_slave; 

    
    // reset generation
    initial begin
        rst <=1;
        #3 rst<=0;
        #5 rst <=1;
    end

    Simplebus s();
    SPI_if spi_if();
    
    defparam DUT.N_CHANNELS = 1;
    SPI DUT(
        .clock(clk),
        .reset(rst),
        .data_valid(out_val),
        .data_out(out),
        .MISO(miso),
        .SCLK(sclk_in),
        .MOSI(mosi),
        .SS(ss_in),
        .simple_bus(s),
        .SPI_write_data(SPI_write_data),
        .SPI_write_valid(SPI_write_valid)
    );

    simplebus_BFM BFM;
    SPI_BFM spi_bfm;

    initial begin
        //INITIAL SETTINGS AND INSTANTIATIONS OF CLASSES
        BFM = new(s,1);
        spi_bfm = new(spi_if,1);
        ss_slave <= 0;
        spi_mode <=spi_mode_master;
        sclk_en <= 0;
        SPI_write_valid <= 0;
        SPI_write_data <= 0;

        //TEST MASTER MODE
        #10 -> slave_task_start;
        #2 -> master_task_start;
    end
    


    logic [spi_width-1:0] slave_data_s = 0;
    logic [spi_width-1:0] slave_data_e = 0;
    logic [spi_width-1:0] slave_data_r = 0;
    logic [spi_width-1:0] master_data_s =0;
    logic [spi_width-1:0] master_data_e =0;
    logic [spi_width-1:0] master_data_r =0;
    
    initial begin : slave
        @(slave_task_start);
        forever begin
            slave_data_s = $urandom;
            spi_bfm.transfer(slave_data_s, spi_width,master_data_r);
            slave_data_e = slave_data_s;
        end
    end


    initial begin : master
        @(master_task_start);
            #10 BFM.write(32'h43C00000,31'h131c2);
            #5 BFM.write(32'h43C00004,31'h1b);
            
        forever begin
            #5 master_data_s = $urandom;
            BFM.write(32'h43C00008,master_data_s);
            //BFM.write(32'h43C00008,31'h000);
            #5 BFM.write(32'h43C0000C,31'h0);
            BFM.read(32'h43C00010,slave_data_r);
            master_data_e <= master_data_s;
            #2->transaction_check;
        end
    end
    
    logic trans_check = 0;
    initial begin: test_checker
        @(transaction_check);
        trans_check <= 1;
        assert (slave_data_e[11:0] == slave_data_r[11:0]) 
        else begin
            $display("MISO SIDE ERROR: expected value %h | recived value %h", slave_data_e[11:0], slave_data_r[11:0]);
            $stop();
        end
        assert (master_data_e[11:0] == master_data_r[11:0]) 
        else begin
            $display("MISO SIDE ERROR: expected value %h | recived value %h", master_data_e[11:0], master_data_r[11:0]);
            $stop();
        end
        #1 trans_check <= 0;
    end

endmodule