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
    wire sda_drive; 
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

    event transfer_done;

    reg write_test, read_test;

    initial begin
        i2c_axi.initialize_master();
        enable <= 0;
        @(reset_done);
        #10;
        enable <= 1;
        forever begin
            if(write_test)begin
                i2c_axi.write(4, 'h01);
                i2c_axi.write(8, 'h60);
                i2c_axi.write(0, 'h4e);
            end

            if(read_test)begin
                i2c_axi.write(4, 'h02);
                i2c_axi.write(8, 'h00);
                i2c_axi.write(0, 'h14e);
            end
            @(transfer_done);
            #10000;    
        end
        
    end

    int write_count = 0;
    initial begin
        write_test = 1;
        read_test = 0;
        @(reset_done);
        while(write_count<3)begin
            @(transfer_done);
            write_count++;
        end

        write_test = 0;
        read_test = 1;
        
    end


    reg scl_prev, sda_prev;
    
    wire scl_negedge = scl_prev & ~SCL;
    wire scl_posedge = ~scl_prev & SCL;

    wire sda_negedge = sda_prev & ~SDA;
    wire sda_posedge = ~sda_prev & SDA;


    always_ff @(posedge clock)begin
        scl_prev <= SCL;
        sda_prev <= SDA;
    end


    integer bit_count = 0;
    reg in_transmission = 0;
    wire in_ack_period = bit_count == 8;
    reg [7:0] captured_data = 8'h00;

    reg [7:0] address = 8'h00;
    reg [7:0] register = 8'h00;
    reg [7:0] data = 8'h00;
    
    enum logic [1:0] { 
        slave_addr = 0,
        register_addr = 1,
        data_phase = 2
    } rx_phase = slave_addr;
    
    assign sda_drive = (in_transmission && in_ack_period) ? 1'b0 : 1'bz;

    always_ff @(posedge clock)begin
        if(SCL & sda_negedge)begin
            in_transmission <= 1;
            bit_count <= 0;
            captured_data <= 0;
        end

        if(scl_posedge)begin
            if(bit_count < 8) begin
                captured_data <= {captured_data[6:0], SDA};
            end

            if(bit_count == 7)begin
                bit_count++;
            end else if(bit_count == 8) begin
                bit_count <= 0;
                if(rx_phase == slave_addr) begin
                    rx_phase <= register_addr;
                    address <= captured_data [7:1];
                end else if(rx_phase == register_addr)begin
                    rx_phase <= data_phase;
                    register <= captured_data;
                end else begin
                    data <= captured_data;
                end
            end else begin
                bit_count++;
            end
        end
        if(SCL & sda_posedge)begin
            ->transfer_done;
            rx_phase <= slave_addr;
            in_transmission <= 0;
        end
    end



endmodule