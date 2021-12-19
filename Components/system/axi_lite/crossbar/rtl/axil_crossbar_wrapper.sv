


module	axil_crossbar_interface #(
		parameter integer DATA_WIDTH = 32,
		parameter integer ADDR_WIDTH = 32,
		parameter	NM = 4,
		parameter	NS = 8,
		parameter	[NS*ADDR_WIDTH-1:0]	SLAVE_ADDR = {
			3'b111,  {(ADDR_WIDTH-3){1'b0}},
			3'b110,  {(ADDR_WIDTH-3){1'b0}},
			3'b101,  {(ADDR_WIDTH-3){1'b0}},
			3'b100,  {(ADDR_WIDTH-3){1'b0}},
			3'b011,  {(ADDR_WIDTH-3){1'b0}},
			3'b010,  {(ADDR_WIDTH-3){1'b0}},
			4'b0001, {(ADDR_WIDTH-4){1'b0}},
			4'b0000, {(ADDR_WIDTH-4){1'b0}} },
		parameter	[NS*ADDR_WIDTH-1:0]	SLAVE_MASK = (NS <= 1) ? { 4'b1111, {(ADDR_WIDTH-4){1'b0}} } : { {(NS-2){ 3'b111, {(ADDR_WIDTH-3){1'b0}} }}, {(2){ 4'b1111, {(ADDR_WIDTH-4){1'b0}} }} },
		parameter [0:0]	OPT_LOWPOWER = 1,
		parameter	OPT_LINGER = 4,
		parameter	LGMAXBURST = 5

	) (

		input wire clock,
		input wire reset,
        axi_lite.slave s1,
        axi_lite.slave s2,
        axi_lite.slave m1,
        axi_lite.slave m2
	);

    axilxbar #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NM(NM),
        .NS(NS),
        .SLAVE_ADDR(SLAVE_ADDR),
        .SLAVE_MASK(SLAVE_MASK),
        .OPT_LOWPOWER(OPT_LOWPOWER),
        .OPT_LINGER(OPT_LINGER),
        .LGMAXBURST(LGMAXBURST)
    ) inner_crossbar(
        .clock(clock),
        .reset(reset),
        .S_AXI_AWADDR({axi_m2.AWADDR, axi_m1.AWADDR}),
        .S_AXI_AWPROT(0),
        .S_AXI_AWVALID({axi_m2.AWVALID, axi_m1.AWVALID}),
        .S_AXI_AWREADY({axi_m2.AWREADY, axi_m1.AWREADY}),
        .S_AXI_WDATA({axi_m2.WDATA, axi_m1.WDATA}),
        .S_AXI_WSTRB({axi_m2.WSTRB, axi_m1.WSTRB}),
        .S_AXI_WVALID({axi_m2.WVALID, axi_m1.WVALID}),
        .S_AXI_WREADY({axi_m2.WREADY, axi_m1.WREADY}),
        .S_AXI_BRESP({axi_m2.BRESP, axi_m1.BRESP}),
        .S_AXI_BVALID({axi_m2.BVALID, axi_m1.BVALID}),
        .S_AXI_BREADY({axi_m2.BREADY, axi_m1.BREADY}),
        .S_AXI_ARADDR({axi_m2.ARADDR, axi_m1.ARADDR}),
        .S_AXI_ARPROT(0),
        .S_AXI_ARVALID({axi_m2.ARVALID, axi_m1.ARVALID}),
        .S_AXI_ARREADY({axi_m2.ARREADY, axi_m1.ARREADY}),
        .S_AXI_RDATA({axi_m2.RDATA, axi_m1.RDATA}),
        .S_AXI_RRESP({axi_m2.RRESP, axi_m1.RRESP}),
        .S_AXI_RVALID({axi_m2.RVALID, axi_m1.RVALID}),
        .S_AXI_RREADY({axi_m2.RREADY, axi_m1.RREADY}),

        .M_AXI_AWADDR({axi_s2.AWADDR, axi_s1.AWADDR}),
        .M_AXI_AWPROT(),
        .M_AXI_AWVALID({axi_s2.AWVALID, axi_s1.AWVALID}),
        .M_AXI_AWREADY({axi_s2.AWREADY, axi_s1.AWREADY}),
        .M_AXI_WDATA({axi_s2.WDATA, axi_s1.WDATA}),
        .M_AXI_WSTRB({axi_s2.WSTRB, axi_s1.WSTRB}),
        .M_AXI_WVALID({axi_s2.WVALID, axi_s1.WVALID}),
        .M_AXI_WREADY({axi_s2.WREADY, axi_s1.WREADY}),
        .M_AXI_BRESP({axi_s2.BRESP, axi_s1.BRESP}),
        .M_AXI_BVALID({axi_s2.BVALID, axi_s1.BVALID}),
        .M_AXI_BREADY({axi_s2.BREADY, axi_s1.BREADY}),
        .M_AXI_ARADDR({axi_s2.ARADDR, axi_s1.ARADDR}),
        .M_AXI_ARPROT(),
        .M_AXI_ARVALID({axi_s2.ARVALID, axi_s1.ARVALID}),
        .M_AXI_ARREADY({axi_s2.ARREADY, axi_s1.ARREADY}),
        .M_AXI_RDATA({axi_s2.RDATA, axi_s1.RDATA}),
        .M_AXI_RRESP({axi_s2.RRESP, axi_s1.RRESP}),
        .M_AXI_RVALID({axi_s2.RVALID, axi_s1.RVALID}),
        .M_AXI_RREADY({axi_s2.RREADY, axi_s1.RREADY})
    );



    

endmodule