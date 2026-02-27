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
module tmp100_read_tb();
    reg clock, reset;


    wire SDA, SCL;
    reg sda_drive; 
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

        i2c_axi.write(4, 'h02);
        i2c_axi.write(8, 'h00);
        i2c_axi.write(0, 'h14e);
        
    end



    logic [15:0] temp_data = 16'h17c0; 

    initial begin
        sda_drive = 1'bz;
        
        forever begin
            // 1. Wait for START Condition
            @(negedge SDA iff SCL == 1);
            $display("[%0t] I2C START detected", $time);
            
            // 2. Capture Address Byte (8 bits)
            repeat (8) @(posedge SCL);
            
            // 3. Drive ACK for Address
            @(negedge SCL);
            sda_drive = 1'b0;
            @(negedge SCL);
            
            // 4. Drive Data Byte (Slave -> Master)
            // We drive on negedge SCL so it's stable for Master's posedge
            for (int i = 7; i >= 0; i--) begin
                sda_drive = temp_data[8+i];
                @(negedge SCL);
            end
            
            // 5. Release SDA for Master's ACK/NACK
            sda_drive = 1'bz;
            @(posedge SCL); 
            // 6. Send SECOND Byte (LSB)
            @(negedge SCL);
            for (int i = 7; i >= 0; i--) begin
                sda_drive = temp_data[i];
                @(negedge SCL);
            end
            
            // 7. Release for Master's NACK
            sda_drive = 1'bz;

            // 8. Wait for STOP
            @(posedge SDA iff SCL == 1);
            $display("[%0t] I2C STOP detected", $time);

        end
    end

endmodule