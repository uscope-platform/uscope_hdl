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
module tmp100_tb();
    reg clock, reset;


    wire SDA, SCL;
    reg sda_drive = 1'bz; 
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

    axi_lite i2c_axi();

    reg enable;
    tmp100 driver(
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .SDA(SDA),
        .SCL(SCL),
        .axi_in(i2c_axi)
    );

    initial begin
        i2c_axi.initialize_master();
        enable <= 0;
        @(reset_done);
        #10;
        enable <= 1;
        forever begin
            i2c_axi.write(0, 'hbe);
            i2c_axi.write(4, 'hfe);
            i2c_axi.write(8, 'hca);
            #100;
        end
        
    end


endmodule