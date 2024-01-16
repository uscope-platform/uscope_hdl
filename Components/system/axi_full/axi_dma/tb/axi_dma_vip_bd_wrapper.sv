`timescale 1 ps / 1 ps
`include "interfaces.svh"

module axi_dma_vip_bd_wrapper (
    input wire clock,
    input wire reset,
    AXI.slave axi_in
);

  axi_dma_vip_bd vip_bd_i (
        .aclk_0(clock),
        .aresetn_0(reset),
        .S_AXI_0_araddr(axi_in.ARADDR),
        .S_AXI_0_arburst(axi_in.ARBURST),
        .S_AXI_0_arcache(axi_in.ARCACHE),
        .S_AXI_0_arid(axi_in.ARID),
        .S_AXI_0_arlen(axi_in.ARLEN),
        .S_AXI_0_arlock(axi_in.ARLOCK),
        .S_AXI_0_arprot(axi_in.ARPROT),
        .S_AXI_0_arqos(axi_in.ARQOS),
        .S_AXI_0_arready(axi_in.ARREADY),
        .S_AXI_0_arregion(axi_in.ARREGION),
        .S_AXI_0_arsize(axi_in.ARSIZE),
        .S_AXI_0_arvalid(axi_in.ARVALID),
        .S_AXI_0_awaddr(axi_in.AWADDR),
        .S_AXI_0_awburst(axi_in.AWBURST),
        .S_AXI_0_awcache(axi_in.AWCACHE),
        .S_AXI_0_awid(axi_in.AWID),
        .S_AXI_0_awlen(axi_in.AWLEN),
        .S_AXI_0_awlock(axi_in.AWLOCK),
        .S_AXI_0_awprot(axi_in.AWPROT),
        .S_AXI_0_awqos(axi_in.AWQOS),
        .S_AXI_0_awready(axi_in.AWREADY),
        .S_AXI_0_awregion(axi_in.AWREGION),
        .S_AXI_0_awsize(axi_in.AWSIZE),
        .S_AXI_0_awvalid(axi_in.AWVALID),
        .S_AXI_0_bid(axi_in.BID),
        .S_AXI_0_bready(axi_in.BREADY),
        .S_AXI_0_bresp(axi_in.BRESP),
        .S_AXI_0_bvalid(axi_in.BVALID),
        .S_AXI_0_rdata(axi_in.RDATA),
        .S_AXI_0_rid(axi_in.RID),
        .S_AXI_0_rlast(axi_in.RLAST),
        .S_AXI_0_rready(axi_in.RREADY),
        .S_AXI_0_rresp(axi_in.RRESP),
        .S_AXI_0_rvalid(axi_in.RVALID),
        .S_AXI_0_wdata(axi_in.WDATA),
        .S_AXI_0_wlast(axi_in.WLAST),
        .S_AXI_0_wready(axi_in.WREADY),
        .S_AXI_0_wstrb(axi_in.WSTRB),
        .S_AXI_0_wvalid(axi_in.WVALID)
    );
endmodule
