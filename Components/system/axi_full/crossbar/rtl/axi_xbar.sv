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

`include "interfaces.svh"

module axi_xbar #(
        parameter integer DATA_WIDTH = 32,
        parameter integer ADDR_WIDTH = 32,
        parameter integer ID_WIDTH = 4,
        parameter NM = 4,
        parameter NS = 8,
        parameter [ADDR_WIDTH-1:0] SLAVE_ADDR [NS-1:0] = '{NS{0}},
        parameter [ADDR_WIDTH-1:0] SLAVE_MASK [NS-1:0] =  '{NS{0}},
        parameter [0:0] OPT_LOWPOWER = 1,
        parameter OPT_LINGER = 4,
        parameter LGMAXBURST = 5
    ) (
        input wire clock,
        input wire reset,
        AXI.slave masters [NM-1:0],
        AXI.master slaves [NS-1:0]
    );

    localparam STROBE_WIDTH = DATA_WIDTH/8;

    // SLAVE INTERFACES FLATTENING
    wire [NM-1:0] S_AXI_AWVALID;
    wire [NM*8-1:0] S_AXI_AWLEN;
    wire [NM*3-1:0] S_AXI_AWSIZE;
    wire [NM*2-1:0] S_AXI_AWBURST;
    wire [NM-1:0] S_AXI_AWLOCK;
    wire [NM*4-1:0] S_AXI_AWCACHE;
    wire [NM*4-1:0] S_AXI_AWQOS;
    wire [NM*ID_WIDTH-1:0] S_AXI_AWID;
    wire [NM*DATA_WIDTH-1:0] S_AXI_WDATA;
    wire [NM-1:0] S_AXI_WVALID;
    wire [NM-1:0] S_AXI_WLAST;
    wire [NM-1:0] S_AXI_BREADY;
    wire [NM-1:0] S_AXI_ARVALID;
    wire [NM-1:0] S_AXI_RREADY;
    wire [NM-1:0] S_AXI_AWREADY;
    wire [NM-1:0] S_AXI_WREADY;
    wire [NM-1:0] S_AXI_BVALID;
    wire [NM-1:0] S_AXI_ARREADY;
    wire [NM-1:0] S_AXI_RVALID;
    wire [NM*DATA_WIDTH-1:0]  S_AXI_RDATA;
    wire [NM*STROBE_WIDTH-1:0] S_AXI_WSTRB;
    wire [NM*ADDR_WIDTH-1:0] S_AXI_AWADDR;
    wire [NM*ADDR_WIDTH-1:0] S_AXI_ARADDR;
    wire [NM*2-1:0] S_AXI_BRESP;
    wire [NM*ID_WIDTH-1:0] S_AXI_BID;
    wire [NM-1:0] S_AXI_RLAST;
    wire [NM*2-1:0] S_AXI_RRESP;
    wire [NM*3-1:0] S_AXI_AWPROT;
    wire [NM*3-1:0] S_AXI_ARPROT;
    wire [NM*8-1:0] S_AXI_ARLEN;
    wire [NM*3-1:0] S_AXI_ARSIZE;
    wire [NM*2-1:0] S_AXI_ARBURST;
    wire [NM-1:0] S_AXI_ARLOCK;
    wire [NM*4-1:0] S_AXI_ARCACHE;
    wire [NM*4-1:0] S_AXI_ARQOS;
    wire [NM*ID_WIDTH-1:0] S_AXI_ARID;
    wire [NM*ID_WIDTH-1:0] S_AXI_RID;

    genvar i;
    generate
        for(i = 0; i< NM; i = i + 1) begin
            
            // WRITE ADDRESS CHANNEL FLATTENING
            assign S_AXI_AWVALID[i] =  slaves[i].AWVALID;
            assign slaves[i].AWREADY = S_AXI_AWREADY[i];
            assign S_AXI_AWADDR[i*ADDR_WIDTH +: ADDR_WIDTH] = slaves[i].AWADDR;
            assign S_AXI_AWPROT[i*3 +: 3] = slaves[i].AWPROT;
            assign S_AXI_AWLEN[i*8 +: 7] = slaves[i].AWLEN;
            assign S_AXI_AWSIZE[i*3 +: 3] = slaves[i].AWSIZE;
            assign S_AXI_AWBURST[i*2 +: 2] = slaves[i].AWBURST;
            assign S_AXI_AWLOCK[i] = slaves[i].AWLOCK;
            assign S_AXI_AWCACHE[i*3 +: 3] = slaves[i].AWCACHE;
            assign S_AXI_AWQOS[i*3 +: 3] = slaves[i].AWQOS;
            assign S_AXI_AWID[i*ID_WIDTH +: ID_WIDTH] = slaves[i].AWID;
            

            // READ ADDRESS CHANNEL FLATTENING
            assign S_AXI_ARADDR[i*ADDR_WIDTH +: ADDR_WIDTH] = slaves[i].ARADDR;
            assign S_AXI_ARVALID[i] = slaves[i].ARVALID;
            assign slaves[i].ARREADY = S_AXI_ARREADY[i];
            assign S_AXI_ARPROT[i*3 +: 3] = slaves[i].ARPROT;
            assign S_AXI_ARLEN[i*8 +: 7] = slaves[i].ARLEN;
            assign S_AXI_ARSIZE[i*3 +: 3] = slaves[i].ARSIZE;
            assign S_AXI_ARBURST[i*2 +: 2] = slaves[i].ARBURST;
            assign S_AXI_ARLOCK[i] = slaves[i].ARLOCK;
            assign S_AXI_ARCACHE[i*3 +: 3] = slaves[i].ARCACHE;
            assign S_AXI_ARQOS[i*3 +: 3] = slaves[i].ARQOS;
            assign S_AXI_ARID[i*ID_WIDTH +: ID_WIDTH] = slaves[i].ARID;
            

            // WRITE DATA CHANNEL FLATTENING
            assign S_AXI_WLAST[i] = slaves[i].WLAST;
            assign S_AXI_WVALID[i] = slaves[i].WVALID;
            assign slaves[i].WREADY = S_AXI_WREADY[i];
            assign S_AXI_WDATA[i*DATA_WIDTH +: DATA_WIDTH] = slaves[i].WDATA;
            assign S_AXI_WSTRB[i*STROBE_WIDTH +: STROBE_WIDTH] = slaves[i].WSTRB;
            
            // READ DATA/RESPONSE CHANNEL FLATTENING

            assign slaves[i].RID = S_AXI_RID[i*ID_WIDTH +: ID_WIDTH];
            assign slaves[i].RLAST = S_AXI_RLAST[i];
            assign slaves[i].RDATA = S_AXI_RDATA[i*DATA_WIDTH +: DATA_WIDTH];
            assign slaves[i].RVALID = S_AXI_RVALID[i];
            assign S_AXI_RREADY[i] = slaves[i].RREADY;
            assign slaves[i].RRESP = S_AXI_RRESP[i*2 +: 2];
            
            // WRITE RESPONSE CHANNEL
            assign slaves[i].BVALID = S_AXI_BVALID[i];
            assign S_AXI_BREADY[i] = slaves[i].BREADY;
            assign slaves[i].BRESP = S_AXI_BRESP[i*2 +: 2];
            assign slaves[i].BID = S_AXI_BID[i*ID_WIDTH +: ID_WIDTH];
            
        end    
    endgenerate
    

    // MASTER INTERFACES FLATTENING
    wire [NS*ADDR_WIDTH-1:0] M_AXI_AWADDR;
    wire [NS-1:0] M_AXI_AWVALID;
    wire [NS-1:0] M_AXI_AWREADY;
    wire [NS*8-1:0] M_AXI_AWLEN;
    wire [NS*3-1:0] M_AXI_AWSIZE;
    wire [NS*2-1:0] M_AXI_AWBURST;
    wire [NS*4-1:0] M_AXI_AWCACHE;
    wire [NS-1:0] M_AXI_AWLOCK;
    wire [NS*4-1:0] M_AXI_AWQOS;
    wire [NS*ID_WIDTH-1:0] M_AXI_AWID;
    wire [NS*DATA_WIDTH-1:0] M_AXI_WDATA;
    wire [NS-1:0] M_AXI_WLAST;
    wire [NS*DATA_WIDTH/8-1:0] M_AXI_WSTRB;
    wire [NS-1:0] M_AXI_WVALID;
    wire [NS-1:0] M_AXI_WREADY;
    wire [NS*2-1:0] M_AXI_BRESP;
    wire [NS-1:0] M_AXI_BVALID;
    wire [NS-1:0] M_AXI_BID;
    wire [NS-1:0] M_AXI_BREADY;
    wire [NS*ADDR_WIDTH-1:0] M_AXI_ARADDR;
    wire [NS-1:0] M_AXI_ARVALID;
    wire [NS-1:0] M_AXI_ARREADY;
    wire [NS*DATA_WIDTH-1:0] M_AXI_RDATA;
    wire [NS*2-1:0] M_AXI_RRESP;
    wire [NS-1:0] M_AXI_RID;
    wire [NS-1:0] M_AXI_RVALID;
    wire [NS-1:0] M_AXI_RLAST;
    wire [NS-1:0] M_AXI_RREADY;
    wire [NS*3-1:0] M_AXI_AWPROT;
    wire [NS*3-1:0] M_AXI_ARPROT;
    wire [NS*8-1:0] M_AXI_ARLEN;
    wire [NS*3-1:0] M_AXI_ARSIZE;
    wire [NS*2-1:0] M_AXI_ARBURST;
    wire [NS*4-1:0] M_AXI_ARCACHE;
    wire [NS-1:0] M_AXI_ARLOCK;
    wire [NS*ID_WIDTH-1:0] M_AXI_ARID;
    wire [NS*4-1:0] M_AXI_ARQOS;
        

    generate
        for(i = 0; i< NS; i = i + 1) begin
            
            // WRITE ADDRESS CHANNEL FLATTENING
            assign masters[i].AWVALID = M_AXI_AWVALID[i];
            assign M_AXI_AWREADY[i] = masters[i].AWREADY;
            assign masters[i].AWADDR  = M_AXI_AWADDR[i*ADDR_WIDTH +: ADDR_WIDTH];
            assign masters[i].AWLEN = M_AXI_AWLEN[i*8 +: 8];
            assign masters[i].AWSIZE = M_AXI_AWSIZE[i*3 +: 8];
            assign masters[i].AWBURST = M_AXI_AWBURST[i*2 +: 2];
            assign masters[i].AWCACHE = M_AXI_AWCACHE[i*4 +: 4];
            assign masters[i].AWPROT = M_AXI_AWPROT[i*3 +: 3];
            assign masters[i].AWLOCK = M_AXI_AWLOCK[i];
            assign masters[i].AWID  = M_AXI_AWID[i*ID_WIDTH +: ID_WIDTH];
            assign masters[i].AWQOS = M_AXI_AWQOS[i*4 +: 4];

            // READ ADDRESS CHANNEL FLATTENING
            assign masters[i].ARADDR = M_AXI_ARADDR[i*ADDR_WIDTH +: ADDR_WIDTH];
            assign masters[i].ARVALID = M_AXI_ARVALID[i];
            assign M_AXI_ARREADY[i] = masters[i].ARREADY;
            assign masters[i].ARLEN = M_AXI_ARLEN[i*8 +: 8];
            assign masters[i].ARSIZE = M_AXI_ARSIZE[i*3 +: 8];
            assign masters[i].ARBURST = M_AXI_ARBURST[i*2 +: 2];
            assign masters[i].ARCACHE = M_AXI_ARCACHE[i*4 +: 4];
            assign masters[i].ARPROT = M_AXI_ARPROT[i*3 +: 3];
            assign masters[i].ARLOCK = M_AXI_ARLOCK[i];
            assign masters[i].ARID  = M_AXI_ARID[i*ID_WIDTH +: ID_WIDTH];
            assign masters[i].ARQOS = M_AXI_ARQOS[i*4 +: 4];

            // WRITE DATA CHANNEL FLATTENING
            assign masters[i].WVALID = M_AXI_WVALID[i];
            assign masters[i].WLAST = M_AXI_WLAST[i];
            assign M_AXI_WREADY[i] = masters[i].WREADY;
            assign masters[i].WDATA = M_AXI_WDATA[i*DATA_WIDTH +: DATA_WIDTH];
            assign masters[i].WSTRB = M_AXI_WSTRB[i*STROBE_WIDTH +: STROBE_WIDTH];
            
            // READ DATA/RESPONSE CHANNEL FLATTENING
            assign M_AXI_RDATA[i*DATA_WIDTH +: DATA_WIDTH] = masters[i].RDATA;
            assign M_AXI_RVALID[i] = masters[i].RVALID;
            assign M_AXI_RLAST[i] = masters[i].RLAST;
            assign masters[i].RREADY = M_AXI_RREADY[i];
            assign M_AXI_RID[i] = masters[i].RID;
            assign M_AXI_RRESP[i*2 +: 2] = masters[i].RRESP;
            
            // WRITE RESPONSE CHANNEL
            assign M_AXI_BVALID[i] = masters[i].BVALID;
            assign masters[i].BREADY = M_AXI_BREADY[i];
            assign M_AXI_BRESP[i*2 +: 2] = masters[i].BRESP;
            assign M_AXI_BID[i] = masters[i].BID;
        
        end    
    endgenerate

	axi_xbar_inner #(
        .C_AXI_DATA_WIDTH(DATA_WIDTH),
        .C_AXI_ADDR_WIDTH(ADDR_WIDTH),
        .C_AXI_ID_WIDTH(ID_WIDTH),
        .NM(NM),
        .NS(NS),
        .SLAVE_ADDR(SLAVE_ADDR),
        .SLAVE_MASK(SLAVE_MASK),
        .OPT_LOWPOWER(OPT_LOWPOWER),   
        .OPT_LINGER(OPT_LINGER),
        .LGMAXBURST(LGMAXBURST)
    ) inner_xbar(
        .S_AXI_ACLK(clock),
        .S_AXI_ARESETN(reset),
        .S_AXI_AWID(S_AXI_AWID),
        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWLEN(S_AXI_AWLEN),
        .S_AXI_AWSIZE(S_AXI_AWSIZE),
        .S_AXI_AWBURST(S_AXI_AWBURST),
        .S_AXI_AWLOCK(S_AXI_AWLOCK),
        .S_AXI_AWCACHE(S_AXI_AWCACHE),
        .S_AXI_AWPROT(S_AXI_AWPROT),
        .S_AXI_AWQOS(S_AXI_AWQOS),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_WLAST(S_AXI_WLAST),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WREADY(S_AXI_WREADY),
        .S_AXI_BID(S_AXI_BID),
        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_BREADY(S_AXI_BREADY),
        .S_AXI_ARID(S_AXI_ARID),
        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARLEN(S_AXI_ARLEN),
        .S_AXI_ARSIZE(S_AXI_AWSIZE),
        .S_AXI_ARBURST(S_AXI_ARBURST),
        .S_AXI_ARLOCK(S_AXI_ARLOCK),
        .S_AXI_ARCACHE(S_AXI_ARCACHE),
        .S_AXI_ARPROT(S_AXI_ARPROT),
        .S_AXI_ARQOS(S_AXI_ARQOS),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_RID(S_AXI_RID),
        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RLAST(S_AXI_RLAST),
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RREADY(S_AXI_RREADY),

        .M_AXI_AWID(M_AXI_AWID),
        .M_AXI_AWADDR(M_AXI_AWADDR),
        .M_AXI_AWLEN(M_AXI_AWLEN),
        .M_AXI_AWSIZE(M_AXI_AWSIZE),
        .M_AXI_AWBURST(M_AXI_AWBURST),
        .M_AXI_AWLOCK(M_AXI_AWLOCK),
        .M_AXI_AWCACHE(M_AXI_AWCACHE),
        .M_AXI_AWPROT(M_AXI_AWPROT),
        .M_AXI_AWQOS(M_AXI_ARQOS),
        .M_AXI_AWVALID(M_AXI_AWVALID),
        .M_AXI_AWREADY(M_AXI_AWREADY),
        .M_AXI_WDATA(M_AXI_WDATA),
        .M_AXI_WSTRB(M_AXI_WSTRB),
        .M_AXI_WLAST(M_AXI_WLAST),
        .M_AXI_WVALID(M_AXI_WVALID),
        .M_AXI_WREADY(M_AXI_WREADY),
        .M_AXI_BID(M_AXI_BID),
        .M_AXI_BRESP(M_AXI_BRESP),
        .M_AXI_BVALID(M_AXI_BVALID),
        .M_AXI_BREADY(M_AXI_BREADY),
        .M_AXI_ARID(M_AXI_ARID),
        .M_AXI_ARADDR(M_AXI_ARADDR),
        .M_AXI_ARLEN(M_AXI_ARLEN),
        .M_AXI_ARSIZE(M_AXI_ARLEN),
        .M_AXI_ARBURST(M_AXI_ARBURST),
        .M_AXI_ARLOCK(M_AXI_ARLOCK),
        .M_AXI_ARCACHE(M_AXI_ARCACHE),
        .M_AXI_ARQOS(M_AXI_ARQOS),
        .M_AXI_ARPROT(M_AXI_ARPROT),
        .M_AXI_ARVALID(M_AXI_ARVALID),
        .M_AXI_ARREADY(M_AXI_ARREADY),
        .M_AXI_RID(M_AXI_RID),
        .M_AXI_RDATA(M_AXI_RDATA),
        .M_AXI_RRESP(M_AXI_RRESP),
        .M_AXI_RLAST(M_AXI_RLAST),
        .M_AXI_RVALID(M_AXI_RVALID),
        .M_AXI_RREADY(M_AXI_RREADY)
	);


    

endmodule