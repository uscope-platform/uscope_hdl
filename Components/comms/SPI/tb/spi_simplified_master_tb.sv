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

module spi_simplified_master_tb();

    logic clock, reset;

    localparam N_CHANNELS=4;
    localparam  msb_first = 1;

    wire [N_CHANNELS-1:0] mosi;
    wire sclk;
    wire ss;
    reg [N_CHANNELS-1:0] miso;

    initial clock = 1;
    always #0.5 clock = ~clock;
    event reset_done;

    axi_lite ctrl_axi();
    axi_stream spi_in();
    axi_stream spi_out();

    spi_simplified_master#(
        .N_CHANNELS(4),
        .REGISTERS_WIDTH(16),
        .OUTPUT_WIDTH(32),
        .DEFAULT_LENGTH(16)
    )UUT(
        .clock(clock),
        .reset(reset),
        .miso(miso),
        .sclk(sclk),
        .mosi(mosi),
        .ss(ss),
        .axi_in(ctrl_axi),
        .spi_data_in(spi_in),
        .spi_data_out(spi_out)
    );


    initial begin
        reset <=1;
        #3 reset<=0;
        #5 reset <=1;
        ->reset_done;
    end

    initial begin
        miso <= 0;
        @(reset_done);
    end



endmodule
