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

`timescale 10ns / 1ns

// axi_watchdog with plain ports instead of AXI interfaces: Verilator can not have interface ports on the top level
// module, so this is what the SystemC testbench is connected to. The ports are the signals of the interfaces in lower
// case after the name of the interface, axi_in for the one the device is a slave of and axi_out for the one it drives,
// which is what sctb::axi_driver and sctb::axi_responder connect. The timeout is short so that the test is quick
module axi_watchdog_shim #(parameter TIMEOUT = 64) (
    input wire clock,
    input wire reset,
    input wire axi_in_awid,
    input wire [31:0] axi_in_awaddr,
    input wire [7:0] axi_in_awlen,
    input wire [2:0] axi_in_awsize,
    input wire [1:0] axi_in_awburst,
    input wire axi_in_awlock,
    input wire [3:0] axi_in_awcache,
    input wire [2:0] axi_in_awprot,
    input wire [3:0] axi_in_awqos,
    input wire [3:0] axi_in_awregion,
    input wire axi_in_awuser,
    input wire axi_in_awvalid,
    output wire axi_in_awready,
    input wire [31:0] axi_in_wdata,
    input wire [3:0] axi_in_wstrb,
    input wire axi_in_wlast,
    input wire axi_in_wuser,
    input wire axi_in_wvalid,
    output wire axi_in_wready,
    output wire [1:0] axi_in_bid,
    output wire [1:0] axi_in_bresp,
    output wire axi_in_buser,
    output wire axi_in_bvalid,
    input wire axi_in_bready,
    input wire axi_in_arid,
    input wire [31:0] axi_in_araddr,
    input wire [7:0] axi_in_arlen,
    input wire [2:0] axi_in_arsize,
    input wire [1:0] axi_in_arburst,
    input wire axi_in_arlock,
    input wire [3:0] axi_in_arcache,
    input wire [2:0] axi_in_arprot,
    input wire [3:0] axi_in_arqos,
    input wire [3:0] axi_in_arregion,
    input wire axi_in_aruser,
    input wire axi_in_arvalid,
    output wire axi_in_arready,
    output wire axi_in_rid,
    output wire [31:0] axi_in_rdata,
    output wire [1:0] axi_in_rresp,
    output wire axi_in_rlast,
    output wire axi_in_ruser,
    output wire axi_in_rvalid,
    input wire axi_in_rready,
    output wire axi_out_awid,
    output wire [31:0] axi_out_awaddr,
    output wire [7:0] axi_out_awlen,
    output wire [2:0] axi_out_awsize,
    output wire [1:0] axi_out_awburst,
    output wire axi_out_awlock,
    output wire [3:0] axi_out_awcache,
    output wire [2:0] axi_out_awprot,
    output wire [3:0] axi_out_awqos,
    output wire [3:0] axi_out_awregion,
    output wire axi_out_awuser,
    output wire axi_out_awvalid,
    input wire axi_out_awready,
    output wire [31:0] axi_out_wdata,
    output wire [3:0] axi_out_wstrb,
    output wire axi_out_wlast,
    output wire axi_out_wuser,
    output wire axi_out_wvalid,
    input wire axi_out_wready,
    input wire [1:0] axi_out_bid,
    input wire [1:0] axi_out_bresp,
    input wire axi_out_buser,
    input wire axi_out_bvalid,
    output wire axi_out_bready,
    output wire axi_out_arid,
    output wire [31:0] axi_out_araddr,
    output wire [7:0] axi_out_arlen,
    output wire [2:0] axi_out_arsize,
    output wire [1:0] axi_out_arburst,
    output wire axi_out_arlock,
    output wire [3:0] axi_out_arcache,
    output wire [2:0] axi_out_arprot,
    output wire [3:0] axi_out_arqos,
    output wire [3:0] axi_out_arregion,
    output wire axi_out_aruser,
    output wire axi_out_arvalid,
    input wire axi_out_arready,
    input wire axi_out_rid,
    input wire [31:0] axi_out_rdata,
    input wire [1:0] axi_out_rresp,
    input wire axi_out_rlast,
    input wire axi_out_ruser,
    input wire axi_out_rvalid,
    output wire axi_out_rready
);

    AXI #(.ID_WIDTH(1), .USER_WIDTH(1), .DATA_WIDTH(32), .ADDR_WIDTH(32)) axi_in();
    AXI #(.ID_WIDTH(1), .USER_WIDTH(1), .DATA_WIDTH(32), .ADDR_WIDTH(32)) axi_out();

    assign axi_in.AWID = axi_in_awid;
    assign axi_in.AWADDR = axi_in_awaddr;
    assign axi_in.AWLEN = axi_in_awlen;
    assign axi_in.AWSIZE = axi_in_awsize;
    assign axi_in.AWBURST = axi_in_awburst;
    assign axi_in.AWLOCK = axi_in_awlock;
    assign axi_in.AWCACHE = axi_in_awcache;
    assign axi_in.AWPROT = axi_in_awprot;
    assign axi_in.AWQOS = axi_in_awqos;
    assign axi_in.AWREGION = axi_in_awregion;
    assign axi_in.AWUSER = axi_in_awuser;
    assign axi_in.AWVALID = axi_in_awvalid;
    assign axi_in_awready = axi_in.AWREADY;
    assign axi_in.WDATA = axi_in_wdata;
    assign axi_in.WSTRB = axi_in_wstrb;
    assign axi_in.WLAST = axi_in_wlast;
    assign axi_in.WUSER = axi_in_wuser;
    assign axi_in.WVALID = axi_in_wvalid;
    assign axi_in_wready = axi_in.WREADY;
    assign axi_in_bid = axi_in.BID;
    assign axi_in_bresp = axi_in.BRESP;
    assign axi_in_buser = axi_in.BUSER;
    assign axi_in_bvalid = axi_in.BVALID;
    assign axi_in.BREADY = axi_in_bready;
    assign axi_in.ARID = axi_in_arid;
    assign axi_in.ARADDR = axi_in_araddr;
    assign axi_in.ARLEN = axi_in_arlen;
    assign axi_in.ARSIZE = axi_in_arsize;
    assign axi_in.ARBURST = axi_in_arburst;
    assign axi_in.ARLOCK = axi_in_arlock;
    assign axi_in.ARCACHE = axi_in_arcache;
    assign axi_in.ARPROT = axi_in_arprot;
    assign axi_in.ARQOS = axi_in_arqos;
    assign axi_in.ARREGION = axi_in_arregion;
    assign axi_in.ARUSER = axi_in_aruser;
    assign axi_in.ARVALID = axi_in_arvalid;
    assign axi_in_arready = axi_in.ARREADY;
    assign axi_in_rid = axi_in.RID;
    assign axi_in_rdata = axi_in.RDATA;
    assign axi_in_rresp = axi_in.RRESP;
    assign axi_in_rlast = axi_in.RLAST;
    assign axi_in_ruser = axi_in.RUSER;
    assign axi_in_rvalid = axi_in.RVALID;
    assign axi_in.RREADY = axi_in_rready;
    assign axi_out_awid = axi_out.AWID;
    assign axi_out_awaddr = axi_out.AWADDR;
    assign axi_out_awlen = axi_out.AWLEN;
    assign axi_out_awsize = axi_out.AWSIZE;
    assign axi_out_awburst = axi_out.AWBURST;
    assign axi_out_awlock = axi_out.AWLOCK;
    assign axi_out_awcache = axi_out.AWCACHE;
    assign axi_out_awprot = axi_out.AWPROT;
    assign axi_out_awqos = axi_out.AWQOS;
    assign axi_out_awregion = axi_out.AWREGION;
    assign axi_out_awuser = axi_out.AWUSER;
    assign axi_out_awvalid = axi_out.AWVALID;
    assign axi_out.AWREADY = axi_out_awready;
    assign axi_out_wdata = axi_out.WDATA;
    assign axi_out_wstrb = axi_out.WSTRB;
    assign axi_out_wlast = axi_out.WLAST;
    assign axi_out_wuser = axi_out.WUSER;
    assign axi_out_wvalid = axi_out.WVALID;
    assign axi_out.WREADY = axi_out_wready;
    assign axi_out.BID = axi_out_bid;
    assign axi_out.BRESP = axi_out_bresp;
    assign axi_out.BUSER = axi_out_buser;
    assign axi_out.BVALID = axi_out_bvalid;
    assign axi_out_bready = axi_out.BREADY;
    assign axi_out_arid = axi_out.ARID;
    assign axi_out_araddr = axi_out.ARADDR;
    assign axi_out_arlen = axi_out.ARLEN;
    assign axi_out_arsize = axi_out.ARSIZE;
    assign axi_out_arburst = axi_out.ARBURST;
    assign axi_out_arlock = axi_out.ARLOCK;
    assign axi_out_arcache = axi_out.ARCACHE;
    assign axi_out_arprot = axi_out.ARPROT;
    assign axi_out_arqos = axi_out.ARQOS;
    assign axi_out_arregion = axi_out.ARREGION;
    assign axi_out_aruser = axi_out.ARUSER;
    assign axi_out_arvalid = axi_out.ARVALID;
    assign axi_out.ARREADY = axi_out_arready;
    assign axi_out.RID = axi_out_rid;
    assign axi_out.RDATA = axi_out_rdata;
    assign axi_out.RRESP = axi_out_rresp;
    assign axi_out.RLAST = axi_out_rlast;
    assign axi_out.RUSER = axi_out_ruser;
    assign axi_out.RVALID = axi_out_rvalid;
    assign axi_out_rready = axi_out.RREADY;

    axi_watchdog #(.TIMEOUT(TIMEOUT)) watchdog (
        .clock(clock),
        .reset(reset),
        .in(axi_in),
        .out(axi_out)
    );

endmodule
