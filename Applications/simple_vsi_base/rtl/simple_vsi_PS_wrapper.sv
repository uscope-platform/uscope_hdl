
module simple_vsi_PS_wrapper (
    output wire logic_clock,
    output wire [0:0]reset,
    axi_lite.master control_axi,
    AXI.slave data_axi,
    input wire dma_done
  );



    ps PS (
        .logic_clock(logic_clock),
        .reset(reset),
        .control_axi_araddr(control_axi.ARADDR),
        .control_axi_arprot(control_axi.ARPROT),
        .control_axi_arready(control_axi.ARREADY),
        .control_axi_arvalid(control_axi.ARVALID),
        .control_axi_awaddr(control_axi.AWADDR),
        .control_axi_awprot(control_axi.AWPROT),
        .control_axi_awready(control_axi.AWREADY),
        .control_axi_awvalid(control_axi.AWVALID),
        .control_axi_bready(control_axi.BREADY),
        .control_axi_bresp(control_axi.BRESP),
        .control_axi_bvalid(control_axi.BVALID),
        .control_axi_rdata(control_axi.RDATA),
        .control_axi_rready(control_axi.RREADY),
        .control_axi_rresp(control_axi.RRESP),
        .control_axi_rvalid(control_axi.RVALID),
        .control_axi_wdata(control_axi.WDATA),
        .control_axi_wready(control_axi.WREADY),
        .control_axi_wstrb(control_axi.WSTRB),
        .control_axi_wvalid(control_axi.WVALID),
        .data_axi_awaddr(data_axi.AWADDR),
        .data_axi_awprot(data_axi.AWPROT),
        .data_axi_awready(data_axi.AWREADY),
        .data_axi_awvalid(data_axi.AWVALID),
        .data_axi_bready(data_axi.BREADY),
        .data_axi_bresp(data_axi.BRESP),
        .data_axi_bvalid(data_axi.BVALID),
        .data_axi_wdata(data_axi.WDATA),
        .data_axi_wready(data_axi.WREADY),
        .data_axi_wstrb(data_axi.WSTRB),
        .data_axi_wvalid(data_axi.WVALID),
        .dma_done(dma_done)
    );


endmodule