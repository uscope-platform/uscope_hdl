// Copyright 2024 Filippo Savi
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
`include "interfaces.svh"
`include "axi_lite_BFM.svh"

module upsizer_tb();
   

    reg clk;
    reg reset = 0;
    
    axi_stream #(
        .DEST_WIDTH(16),
        .USER_WIDTH(16),
        .DATA_WIDTH(64)
    ) data_in();

    axi_stream #(
        .DEST_WIDTH(16),
        .USER_WIDTH(16),
        .DATA_WIDTH(128)
    ) data_out();

    upsizer #(
        .INPUT_WIDTH(64),
        .OUTPUT_WIDTH(128)
    )UUT(
        .clock(clk),
        .reset(reset),
        .data_in(data_in),
        .data_out(data_out)
    );

    always begin
        clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5;
    end

    reg [31:0] data_prog = 0;
    event restart_data_gen;
    initial begin 
        reset <=1'h0;

        //TESTS
        #30.5 reset <=1'h1;

        data_in.data  <= 0;
        data_in.valid <= 0;
        data_in.tlast <= 0;

        #70;
        forever begin
            for (integer i = 0; i <1024; i = i+1 ) begin
                data_in.valid <= 0;
                wait(data_in.ready==1);
                data_in.data <= i;
                data_in.dest <= i+1000;
                data_in.user <= i+2000;
                data_in.valid <= 1;
                if(i==1023)begin
                    data_in.tlast <= 1;
                end else begin
                    data_in.tlast <= 0;
                end
                data_prog <= data_prog + 1;
                #1;
            end
            data_in.valid <= 0;
            data_in.tlast <= 0;
            @(restart_data_gen);
            #30;
        end
    end

    initial begin
        data_out.ready <= 1;
        #300 data_out.ready <= 0;
        #10 data_out.ready <= 1;
    end

    reg [31:0] check_buf [1023:0];

    reg [31:0] check_ctr = 0;
    always_ff@(posedge clk)begin
        if(data_out.valid)begin
            check_buf[check_ctr] <= data_out.data[31:0];
            check_buf[check_ctr+1] <= data_out.data[95:64];
            check_ctr <= check_ctr + 2;
        end
    end




endmodule