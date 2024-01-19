`timescale 1 ps / 1 ps
`include "interfaces.svh"

module axi_to_axil_vip_bd_wrapper (
    input wire clock,
    input wire reset,
    AXI.slave axi_in
);

  axi_to_axil_vip_bd vip_bd_i (
        .aclk_0(clock),
        .aresetn_0(reset),
        .M_AXI_0_araddr(axi_in.ARADDR),
        .M_AXI_0_arburst(axi_in.ARBURST),
        .M_AXI_0_arcache(axi_in.ARCACHE),
        .M_AXI_0_arid(axi_in.ARID),
        .M_AXI_0_arlen(axi_in.ARLEN),
        .M_AXI_0_arlock(axi_in.ARLOCK),
        .M_AXI_0_arprot(axi_in.ARPROT),
        .M_AXI_0_arqos(axi_in.ARQOS),
        .M_AXI_0_arready(axi_in.ARREADY),
        .M_AXI_0_arregion(axi_in.ARREGION),
        .M_AXI_0_arsize(axi_in.ARSIZE),
        .M_AXI_0_arvalid(axi_in.ARVALID),
        .M_AXI_0_awaddr(axi_in.AWADDR),
        .M_AXI_0_awburst(axi_in.AWBURST),
        .M_AXI_0_awcache(axi_in.AWCACHE),
        .M_AXI_0_awid(axi_in.AWID),
        .M_AXI_0_awlen(axi_in.AWLEN),
        .M_AXI_0_awlock(axi_in.AWLOCK),
        .M_AXI_0_awprot(axi_in.AWPROT),
        .M_AXI_0_awqos(axi_in.AWQOS),
        .M_AXI_0_awready(axi_in.AWREADY),
        .M_AXI_0_awregion(axi_in.AWREGION),
        .M_AXI_0_awsize(axi_in.AWSIZE),
        .M_AXI_0_awvalid(axi_in.AWVALID),
        .M_AXI_0_bid(axi_in.BID),
        .M_AXI_0_bready(axi_in.BREADY),
        .M_AXI_0_bresp(axi_in.BRESP),
        .M_AXI_0_bvalid(axi_in.BVALID),
        .M_AXI_0_rdata(axi_in.RDATA),
        .M_AXI_0_rid(axi_in.RID),
        .M_AXI_0_rlast(axi_in.RLAST),
        .M_AXI_0_rready(axi_in.RREADY),
        .M_AXI_0_rresp(axi_in.RRESP),
        .M_AXI_0_rvalid(axi_in.RVALID),
        .M_AXI_0_wdata(axi_in.WDATA),
        .M_AXI_0_wlast(axi_in.WLAST),
        .M_AXI_0_wready(axi_in.WREADY),
        .M_AXI_0_wstrb(axi_in.WSTRB),
        .M_AXI_0_wvalid(axi_in.WVALID)
    );
endmodule
