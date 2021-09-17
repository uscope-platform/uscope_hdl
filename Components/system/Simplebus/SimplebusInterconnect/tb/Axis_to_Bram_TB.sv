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

module axis_to_br_tb ();

    reg [31:0] din;
    reg [31:0]raddr;
    reg ren,rst,clk,ivalid,reading;
    wire memf;
    //Clock generation
    always begin
       clk<=0;
       #0.5 clk<=1;
       #0.5;
    end
    
    //Reset signal 
    initial begin
        rst <=1;
        #5 rst<=0;
        #5 rst<=1;
    end
    
    initial begin
        din <= 0;
        ivalid <= 0;
        forever begin
            #5 din <= $urandom;
            ivalid <=1;
            #1 ivalid <=0;
        end
    end

    always@(posedge clk)begin
        if(!rst)begin
            raddr <=0;
        end else begin
            if(reading)begin
                if(raddr==1023)begin
                    reading <=0;
                    raddr <=0;
                end else begin
                    raddr <= raddr+1;
                end

            end
        end
    end

    always begin
        @(negedge memf);
        #1 reading <= 1;
    end

    AXIS_to_DP DUT (
        .clock(clk),
        .reset(rst), 
        .data_in(din),
        .input_valid(ivalid),
        .read_enable(reading),
        .read_address(raddr),
        .memory_full(memf)
    );

endmodule