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

module spi_cu_tb();

    event testbench_start;

    reg clk, reset, sclk, ss, data;
    axi_lite test_axi();

    spi_cu #(
        .HIGH_RANGE_BIT(0)
    ) UUT (
        .clock(clk),
        .reset(reset),
        .SCLK(sclk),
        .SS(ss),
        .DATA(data),
        .axi_out(test_axi)
    );

    always begin
        clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5;
    end


    initial begin
        test_axi.AWREADY = 1;
        test_axi.WREADY = 1;
        test_axi.ARREADY = 1;
        test_axi.RDATA = 0;
        test_axi.RRESP = 0;
        test_axi.RVALID = 0;
        test_axi.BRESP = 0;
        test_axi.BVALID = 1;
        reset <=1'h1;
        #10 reset <=1'h0;
        #20.5 reset <=1'h1;
        #10 ->testbench_start;
    end

    event send_data, transmission_done, check_done;
    reg[15:0] current_transmission;

    initial begin
        sclk <= 0;
        ss <= 0;
        data = 0;
        @(testbench_start);
        forever begin
            @(send_data);
            ss <= 1;
            #4;
            for(integer i = 15; i>=0; i--)begin
                #2 sclk <= 1;
                data <= current_transmission[15-i];
                #2 sclk <= 0;
            end
            #4;
            ss <= 0;
            ->transmission_done;
        end
    end

    reg [31:0] test_address;
    reg [31:0] test_data;
    reg test_high_bytes;

    initial begin
    test_address <= 0;
    test_data <= 0;
    test_high_bytes <= 0;
    current_transmission <= 0;
    @(testbench_start);
    #50;
    forever begin
        test_address = $urandom();
        test_data = $urandom();
        test_high_bytes =  $urandom();
        if(~test_high_bytes)begin
            current_transmission = {17'b0, test_address[14:0]};
            ->send_data;
            @(transmission_done);
            #5;
            current_transmission = test_data[15:0];
            ->send_data;
            @(transmission_done);
            @(check_done);
            #20;
        end else begin
            current_transmission = test_address[15:0];
            ->send_data;
            @(transmission_done);
            #5;
            current_transmission = test_data[15:0];
            ->send_data;
            @(transmission_done);
            #5;
            current_transmission = test_address[31:16];
            ->send_data;
            @(transmission_done);
            #5;
            current_transmission = test_data[31:16];
            ->send_data;
            @(transmission_done);
            @(check_done);
            #20;
        end

    end

    end

    initial begin
        @(testbench_start);
        forever begin
            @(transmission_done);
            if(test_high_bytes)begin
                @(posedge test_axi.AWVALID);
                assert (test_axi.AWADDR == test_address)
                else begin
                    $display("MISMATCH BETWEEN SENT[%h] AND RECEIVED ADDRESSES[%h]", test_address, test_axi.AWADDR);
                end
                assert (test_axi.WDATA == test_data)
                else begin
                    $display("MISMATCH BETWEEN SENT[%h] AND RECEIVED ADDRESSES[%h]", test_data, test_axi.WDATA);
                end
            end else begin
                @(posedge test_axi.AWVALID);
                assert (test_axi.AWADDR == test_address[14:0])
                else begin
                    $display("MISMATCH BETWEEN SENT[%h] AND RECEIVED ADDRESSES[%h]", test_address, test_axi.AWADDR);
                end
                assert (test_axi.WDATA == test_data[15:0])
                else begin
                    $display("MISMATCH BETWEEN SENT[%h] AND RECEIVED ADDRESSES[%h]", test_data, test_axi.WDATA);
                end
            end
            ->check_done;
        end
    end



endmodule
