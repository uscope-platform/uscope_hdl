// Copyright 2021 Filippo Savi
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


module packet_aggregator_tb();

    reg  clk, reset;

    event config_done;
    

    axi_stream #(
        .DATA_WIDTH(data_width)
    ) data_in();

    axi_stream #(
        .DATA_WIDTH(data_width)
    ) data_out();



    always begin
        clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5;
    end

    packet_aggregator #(
        .DATA_PATH_WIDTH(16),
        .PACKET_START_ADDR(5),
        .PACKET_LENGHT(12)
    )UUT(
        .clock(clk),
        .reset(reset),
        .data_in(data_in),
        .data_out(data_out)
    );


    initial begin
        data_out.ready <= 1;
        data_in.data<= 0;
        data_in.valid <= 0;
        //Initial status
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;

        #50;

        ->config_done;
    end


endmodule