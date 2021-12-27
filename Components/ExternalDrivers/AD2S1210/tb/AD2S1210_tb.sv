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
`include "interfaces.svh"

module AD2S1210_tb();
      reg clk, rst, start;

      Simplebus s();

      wire ss;
      wire mosi;
      reg miso = 0;
      reg spi_mode =0;

      wire [1:0] RES_A;
      wire [1:0] RES_RE;
      wire RES_SAMPLE, RES_RESET;

      ad2s1210_tl_test UUT(
            .clock(clk),
            .reset(rst),
            .R_SDO_RES(miso),
            .R_SDI_RES(mosi),
            .R_WR(ss),
            .R_SCK_RES(sclk),
            .R_A0(RES_A[0]),
            .R_A1(RES_A[1]),
            .R_RE0(RES_RE[0]),
            .R_RE1(RES_RE[1]),
            .R_SAMPLE(RES_SAMPLE),
            .R_RESET(RES_RESET),
            .s(s)
      );

      simplebus_BFM BFM;

      parameter  BASE_ADDRESS = 32'h43c00000;
      parameter  SPI_BASE_ADDRESS = BASE_ADDRESS+'h2C;   
      //clock generation
      initial clk = 0; 
      always #0.5 clk = ~clk; 

      // reset generation
      initial begin
            BFM = new(s,1);
            rst <=1;
            start <= 0;
            #3.5 rst<=0;
            #5 rst <=1;
            #8;

            
            BFM.write(SPI_BASE_ADDRESS + 'h04 ,31'h1c);
            BFM.write(SPI_BASE_ADDRESS + 'h00 ,31'h3E184);
            #500 BFM.write(BASE_ADDRESS + 'h28, 'h16501c14);
            //#100 BFM.write(BASE_ADDRESS + 'h24, 'h0);

            
            #10 BFM.write(BASE_ADDRESS + 'h104, 8000);
            #10 BFM.write(BASE_ADDRESS + 'h108, 300);
            #10 BFM.write(BASE_ADDRESS + 'h10C, 3500);
            #10 BFM.write(BASE_ADDRESS + 'h100, 'h1);
            //#100000 BFM.write(BASE_ADDRESS + 'h104, 'h0);
            //#1400 BFM.write(BASE_ADDRESS + 'h24, 'h1);
    end

    always@(posedge sclk)begin
        miso = $urandom;
    end
   

endmodule