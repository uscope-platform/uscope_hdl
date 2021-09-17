//Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2020.1 (lin64) Build 2902540 Wed May 27 19:54:35 MDT 2020
//Date        : Fri Oct  2 04:34:51 2020
//Host        : ubuntu running 64-bit Ubuntu 20.04.1 LTS
//Command     : generate_target VIP_wrapper.bd
//Design      : VIP_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module dma_vip_wrapper( 
    input wire clock,
    input wire reset,
    output wire dma_done,
    axi_lite axi,
    axi_stream.slave stream
);

    VIP VIP_i (
        .clock(clock),
        .reset(reset),
        .dma_done(dma_done),
        .dma_manager_araddr(axi.ARADDR),
        .dma_manager_arready(axi.ARREADY),
        .dma_manager_arvalid(axi.ARVALID),
        .dma_manager_awaddr(axi.AWADDR),
        .dma_manager_awready(axi.AWREADY),
        .dma_manager_awvalid(axi.AWVALID),
        .dma_manager_bready(axi.BREADY),
        .dma_manager_bresp(axi.BRESP),
        .dma_manager_bvalid(axi.BVALID),
        .dma_manager_rdata(axi.RDATA),
        .dma_manager_rready(axi.RREADY),
        .dma_manager_rresp(axi.RRESP),
        .dma_manager_rvalid(axi.RVALID),
        .dma_manager_wdata(axi.WDATA),
        .dma_manager_wready(axi.WREADY),
        .dma_manager_wvalid(axi.WVALID),
        .uscope_tkeep(0),
        .uscope_tdata(stream.data),
        .uscope_tlast(stream.tlast),
        .uscope_tready(stream.ready),
        .uscope_tvalid(stream.valid)
    );

endmodule
