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
module standalone_reader_tb();
    reg clock, reset;

    localparam gpio = 'h400000000;
    localparam tb = 'h400010000;


    wire SDA, SCL;
    reg sda_drive =  1'bz;
    assign SDA = sda_drive;

    pullup(SDA);
    pullup(SCL);

    //clock generation
    initial clock = 0;
    always #0.5 clock = ~clock;

    event reset_done;
    // reset generation
    initial begin
        reset <=1;
        #3.5 reset<=0;
        #5 reset <=1;
        #8;
        ->reset_done;
    end

    axi_lite #(.ADDR_WIDTH(39)) reader();


    tmp100_standalone_reader DUT(
        .clock(clock),
        .reset(reset),
        .SDA(SDA),
        .SCL(SCL),
        .control_axi(reader)
    );

    initial begin
        reader.initialize_master();
        @(reset_done);
        #100;
        #10 reader.write(gpio, 'h1);
        #10 reader.write(tb + 4, 100000);
        #10 reader.write(tb + 8, 10);
        #10 reader.write(tb , 1);
    end



    tmp100_emulator emu (
        .clock(clock),
        .reset(reset),
        .SDA(SDA),
        .SCL(SCL)
    );


endmodule
