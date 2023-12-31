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
`include "interfaces.svh"

`ifndef AXI_FULL_BFM_SV
`define AXI_FULL_BFM_SV

class axi_full_bfm #(int ID_WIDTH = 1,int USER_WIDTH = 1, int DATA_WIDTH = 32, int ADDR_WIDTH = 12);

    virtual AXI #(ID_WIDTH, USER_WIDTH, DATA_WIDTH, ADDR_WIDTH) bus;
    integer clock_period;

    function new (virtual AXI #(ID_WIDTH, USER_WIDTH, DATA_WIDTH, ADDR_WIDTH) test_bus, integer period);
        begin
            this.bus = test_bus;

            this.bus.ARID <= 0;
            this.bus.ARUSER <= 0;
            this.bus.ARREGION <= 0;
            this.bus.ARQOS <= 0;
            this.bus.ARLOCK <= 0;
            this.bus.ARCACHE <= 0;
            this.bus.ARPROT <= 0;
            this.bus.ARADDR <= 0;
            this.bus.ARVALID <= 0;
            this.bus.ARLEN <= 1;
            this.bus.ARBURST <= 0;
            this.bus.AWSIZE <= 4;
            

            this.bus.AWID <= 0;
            this.bus.AWUSER <= 0;
            this.bus.AWREGION <= 0;
            this.bus.AWQOS <= 0;
            this.bus.AWLOCK <= 0;
            this.bus.AWCACHE <= 0;
            this.bus.AWPROT <= 0;
            this.bus.AWADDR <= 0;
            this.bus.AWVALID <= 0;
            this.bus.AWLEN <= 1;
            this.bus.AWBURST <= 0;
            this.bus.ARSIZE <= 4;

            this.bus.BREADY <= 0;
            this.bus.RREADY <= 0;

            this.bus.WDATA <= 0;
            this.bus.WLAST <= 0;
            this.bus.WUSER <= 0;
            this.bus.WVALID <= 0;
            this.bus.WSTRB <= 0;

            this.clock_period = period;
        end
    endfunction

    task write(input logic [31:0] address, input logic [31:0] data);

        this.bus.AWADDR <= address;
        this.bus.AWVALID <= 1;
        this.bus.WLAST <= 1;
        #1;
        this.bus.AWVALID <= 0;
        this.bus.WDATA <= data;
        this.bus.WVALID <= 1;
        this.bus.WSTRB <= 'hF;
        
        #1;
        this.bus.BREADY <= 1;
        this.bus.WLAST <= 0;
        this.bus.WVALID <= 0;

        this.bus.AWADDR <= 0;
        this.bus.WDATA <= 0;
        this.bus.WSTRB <= 0;
        @(this.bus.BVALID);
        #1;
    endtask

    task  read(input logic [31:0] address, output logic [31:0] data);
        this.bus.ARADDR <= address;
        this.bus.ARVALID <= 1;
        this.bus.RREADY <= 1;
        wait(this.bus.ARREADY);
        #1;
        this.bus.ARVALID <= 0;
        wait(this.bus.RVALID);
        #1;
        data = this.bus.RDATA;
        
        this.bus.RREADY <= 0;
    endtask

endclass

`endif