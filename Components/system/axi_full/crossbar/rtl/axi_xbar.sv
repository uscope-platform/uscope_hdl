////////////////////////////////////////////////////////////////////////////////
// Copyright (C) 2019-2022, Gisselquist Technology, LLC
// Copyright 2023 Filippo Savi
// This file is part of the WB2AXIP project.
//
// The WB2AXIP project contains free software and gateware, licensed under the
// Apache License, Version 2.0 (the "License").  You may not use this project,
// or this file, except in compliance with the License.  You may obtain a copy
// of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
// License for the specific language governing permissions and limitations
// under the License.
//
////////////////////////////////////////////////////////////////////////////////



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
        AXI.slave slaves [NM-1:0],
        AXI.master masters [NS-1:0]
    );

    // Local parameters, derived from those above

    localparam	LGLINGER = (OPT_LINGER>1) ? $clog2(OPT_LINGER+1) : 1;
    localparam	LGNM = (NM>1) ? $clog2(NM) : 1;
    localparam	LGNS = (NS>1) ? $clog2(NS+1) : 1;

    localparam	NMFULL = (NM>1) ? (1<<LGNM) : 1;
    localparam	NSFULL = (NS>1) ? (1<<LGNS) : 2;
    localparam [1:0] INTERCONNECT_ERROR = 2'b11;

    localparam [0:0]	OPT_SKID_INPUT = 0;

    localparam [0:0]	OPT_BUFFER_DECODER = 1;

    localparam	OPT_AWW = 1'b1;

    genvar	N,M;
    integer	iN, iM;

    reg	[NSFULL-1:0]	wrequest		[0:NM-1];
    reg	[NSFULL-1:0]	rrequest		[0:NM-1];
    reg	[NSFULL-1:0]	wrequested		[0:NM];
    reg	[NSFULL-1:0]	rrequested		[0:NM];
    reg	[NS:0] wgrant [0:NM-1] = '{NM{0}};
    reg	[NS:0] rgrant [0:NM-1] = '{NM{0}};
    reg	[NM-1:0] mwgrant = 0;
    reg	[NM-1:0]	mrgrant = 0;
    reg	[NS-1:0]	swgrant;
    reg	[NS-1:0]	srgrant;

    // verilator lint_off UNUSED
    wire	[LGMAXBURST-1:0]	w_mawpending	[0:NM-1];
    wire	[LGMAXBURST-1:0]	wlasts_pending	[0:NM-1];
    wire	[LGMAXBURST-1:0]	w_mrpending	[0:NM-1];
    // verilator lint_on  UNUSED
    reg	[NM-1:0] mwfull = 0;
    reg	[NM-1:0] mrfull = 0;
    reg	[NM-1:0] mwempty = {NM{1'b1}};
    reg	[NM-1:0] mrempty = {NM{1'b1}};
    //
    wire	[LGNS-1:0]		mwindex	[0:NMFULL-1];
    wire	[LGNS-1:0]		mrindex	[0:NMFULL-1];
    wire	[LGNM-1:0]		swindex	[0:NSFULL-1];
    wire	[LGNM-1:0]		srindex	[0:NSFULL-1];

    wire	[NM-1:0]		wdata_expected;

    // The shadow buffers
    wire	[NMFULL-1:0]	m_awvalid, m_arvalid;
    wire	[NMFULL-1:0]	m_wvalid;
    wire	[NM-1:0]	dcd_awvalid, dcd_arvalid;

    wire	[ID_WIDTH-1:0]		m_awid		[0:NMFULL-1];
    wire	[ADDR_WIDTH-1:0]		m_awaddr	[0:NMFULL-1];
    wire	[7:0]				m_awlen		[0:NMFULL-1];
    wire	[2:0]				m_awsize	[0:NMFULL-1];
    wire	[1:0]				m_awburst	[0:NMFULL-1];
    wire	[NMFULL-1:0]			m_awlock;
    wire	[3:0]				m_awcache	[0:NMFULL-1];
    wire	[2:0]				m_awprot	[0:NMFULL-1];
    wire	[3:0]				m_awqos		[0:NMFULL-1];
    //
    wire	[DATA_WIDTH-1:0]		m_wdata		[0:NMFULL-1];
    wire	[DATA_WIDTH/8-1:0]	m_wstrb		[0:NMFULL-1];
    wire	[NMFULL-1:0]			m_wlast;

    wire	[ID_WIDTH-1:0]		m_arid		[0:NMFULL-1];
    wire	[ADDR_WIDTH-1:0]		m_araddr	[0:NMFULL-1];
    wire	[8-1:0]				m_arlen		[0:NMFULL-1];
    wire	[3-1:0]				m_arsize	[0:NMFULL-1];
    wire	[2-1:0]				m_arburst	[0:NMFULL-1];
    wire	[NMFULL-1:0]			m_arlock;
    wire	[4-1:0]				m_arcache	[0:NMFULL-1];
    wire	[2:0]				m_arprot	[0:NMFULL-1];
    wire	[3:0]				m_arqos		[0:NMFULL-1];
    //
    //
    reg	[NM-1:0] berr_valid = 0;
    reg	[ID_WIDTH-1:0]			berr_id		[0:NM-1];
    //
    reg	[NM-1:0] rerr_none = {NM{1'b1}};
    reg	[NM-1:0] rerr_last = 0;
    reg	[8:0]				rerr_outstanding [0:NM-1];
    reg	[ID_WIDTH-1:0]			rerr_id		 [0:NM-1];

    wire	[NM-1:0]	skd_awvalid, skd_awstall;
    wire	[NM-1:0]	skd_arvalid, skd_arstall;
    wire	[ID_WIDTH-1:0]	skd_awid			[0:NM-1];
    wire	[ADDR_WIDTH-1:0]	skd_awaddr			[0:NM-1];
    wire	[8-1:0]		skd_awlen			[0:NM-1];
    wire	[3-1:0]		skd_awsize			[0:NM-1];
    wire	[2-1:0]		skd_awburst			[0:NM-1];
    wire	[NM-1:0]	skd_awlock;
    wire	[4-1:0]		skd_awcache			[0:NM-1];
    wire	[3-1:0]		skd_awprot			[0:NM-1];
    wire	[4-1:0]		skd_awqos			[0:NM-1];
    //
    wire	[ID_WIDTH-1:0]	skd_arid			[0:NM-1];
    wire	[ADDR_WIDTH-1:0]	skd_araddr			[0:NM-1];
    wire	[8-1:0]		skd_arlen			[0:NM-1];
    wire	[3-1:0]		skd_arsize			[0:NM-1];
    wire	[2-1:0]		skd_arburst			[0:NM-1];
    wire	[NM-1:0]	skd_arlock;
    wire	[4-1:0]		skd_arcache			[0:NM-1];
    wire	[3-1:0]		skd_arprot			[0:NM-1];
    wire	[4-1:0]		skd_arqos			[0:NM-1];

    reg	[NSFULL-1:0]	m_axi_wready;
    wire	[NSFULL-1:0]	m_axi_bvalid;
    // Verilator lint_on  UNUSED
    wire	[1:0]		m_axi_bresp	[0:NSFULL-1];
    wire	[ID_WIDTH-1:0]	m_axi_bid	[0:NSFULL-1];

    // Verilator lint_on  UNUSED
    wire	[NSFULL-1:0]	m_axi_rvalid;
    // Verilator lint_on  UNUSED
    //
    wire	[ID_WIDTH-1:0]	m_axi_rid	[0:NSFULL-1];
    wire	[DATA_WIDTH-1:0]	m_axi_rdata	[0:NSFULL-1];
    wire	[NSFULL-1:0]	m_axi_rlast;
    wire	[2-1:0]		m_axi_rresp	[0:NSFULL-1];

    reg	[NM-1:0]	slave_awaccepts;
    reg	[NM-1:0]	slave_waccepts;
    reg	[NM-1:0]	slave_raccepts;

    reg	[NM-1:0]	bskd_valid;
    reg	[NM-1:0]	rskd_valid, rskd_rlast;
    wire [NM-1:0]	bskd_ready;
    wire [NM-1:0] rskd_ready;

    reg	[NSFULL-1:0]	slave_awready, slave_wready, slave_arready;



    generate
        for(M = 0; M<NS; M = M+1)begin
            assign m_axi_bvalid[M] = masters[M].BVALID;
            assign m_axi_bresp[M] = masters[M].BRESP;
            assign m_axi_bid[M] = masters[M].BID;
            assign m_axi_rid[M] = masters[M].RID;
            assign m_axi_rdata[M] = masters[M].RDATA;
            assign m_axi_rresp[M] = masters[M].RRESP;
            assign m_axi_rlast[M] = masters[M].RLAST;
            assign m_axi_rvalid[M]  = masters[M].RVALID;


            assign slave_awready[M] = (~masters[M].AWVALID | masters[M].AWREADY);
            assign slave_wready[M]  = (~masters[M].WVALID  | masters[M].WREADY);
            assign slave_arready[M] = (~masters[M].ARVALID | masters[M].ARREADY);
        end
        for(M = NS; M<NSFULL; M = M+1)begin
            assign m_axi_bvalid[M] = 0;
            assign m_axi_bresp[M] = INTERCONNECT_ERROR;
            assign m_axi_bid[M] = 0;
            assign m_axi_rid[M] = 0;
            assign m_axi_rdata[M] = 0;
            assign m_axi_rresp[M] = INTERCONNECT_ERROR;
            assign m_axi_rlast[M] = 1;
            assign m_axi_rvalid[M] = 0;

            assign slave_awready[M] = 1;
            assign slave_wready[M]  = 1;
            assign slave_arready[M] = 1;
        end
    endgenerate



    ////////////////////////////////////////////////////////////////////////
    // Process our incoming signals: AW*, W*, and AR*
    ////////////////////////////////////////////////////////////////////////

        
	generate 
        for(N=0; N<NM; N=N+1) begin : W1_DECODE_WRITE_REQUEST
            wire [NS:0] wdecode;


            axi_w_addr_skid_buffer #(
                .REGISTER_OUTPUT(OPT_SKID_INPUT),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ID_WIDTH(ID_WIDTH)
            ) awskid (
                .clock(clock),
                .reset(reset),
                .in_valid(slaves[N].AWVALID),
                .in_ready(slaves[N].AWREADY),
                .in_id(slaves[N].AWID),
                .in_addr(slaves[N].AWADDR),
                .in_len(slaves[N].AWLEN),
                .in_size(slaves[N].AWSIZE),
                .in_burst(slaves[N].AWBURST),
                .in_lock(slaves[N].AWLOCK),
                .in_cache(slaves[N].AWCACHE),
                .in_prot(slaves[N].AWPROT),
                .in_qos(slaves[N].AWQOS),
                                    
                .out_valid(skd_awvalid[N]),
                .out_ready(!skd_awstall[N]),

                .out_id(skd_awid[N]),
                .out_addr(skd_awaddr[N]),
                .out_len(skd_awlen[N]),
                .out_size(skd_awsize[N]),
                .out_burst(skd_awburst[N]),
                .out_lock(skd_awlock[N]),
                .out_cache(skd_awcache[N]),
                .out_prot(skd_awprot[N]),
                .out_qos(skd_awqos[N])
            );

            // wraddr, decode the write channel's address request to a
            // particular slave index



            axi_address_decoder #(
                .AW(ADDR_WIDTH),
                .IW(ID_WIDTH),
                .NS(NS),
                .SLAVE_ADDR(SLAVE_ADDR),
                .SLAVE_MASK(SLAVE_MASK),
                .OPT_REGISTERED(OPT_BUFFER_DECODER),
                .OPT_LOWPOWER(OPT_LOWPOWER)
            ) rdaddr (
                .clock(clock),
                .reset(reset),
                .i_valid(skd_awvalid[N]),
                .o_stall(skd_awstall[N]),
                .i_addr(skd_awaddr[N]),
                .i_id(skd_awid[N]),
                .i_len(skd_awlen[N]),
                .i_size(skd_awsize[N]),
                .i_burst(skd_awburst[N]),
                .i_lock(skd_awlock[N]),
                .i_cache(skd_awcache[N]),
                .i_prot(skd_awprot[N]),
                .i_qos(skd_awqos[N]),
                .o_valid(dcd_awvalid[N]),
                .i_stall(!dcd_awvalid[N] || !slave_awaccepts[N]),
                .o_decode(wdecode),
                .o_addr(m_awaddr[N]),
                .o_id(m_awid[N]),
                .o_len(m_awlen[N]),
                .o_size(m_awsize[N]),
                .o_burst(m_awburst[N]),
                .o_lock(m_awlock[N]),
                .o_cache(m_awcache[N]),
                .o_prot(m_awprot[N]),
                .o_qos(m_awqos[N])
            );


            axi_w_data_skid_buffer #(
                .REGISTER_OUTPUT(OPT_SKID_INPUT || OPT_BUFFER_DECODER),
                .DATA_WIDTH(DATA_WIDTH)
            )wskid (
                .clock(clock),
                .reset(reset),
                .in_valid(slaves[N].WVALID),
                .in_ready(slaves[N].WREADY),
                .in_data(slaves[N].WDATA),
                .in_strb(slaves[N].WSTRB),
                .in_last(slaves[N].WLAST),
                
                .out_valid(m_wvalid[N]),
                .out_ready(slave_waccepts[N]),

                .out_data(m_wdata[N]),
                .out_strb(m_wstrb[N]),
                .out_last(m_wlast[N])

            );
            
            // slave_awaccepts
            always @(*) begin
                slave_awaccepts[N] = 1'b1;
                if (!mwgrant[N])
                    slave_awaccepts[N] = 1'b0;
                if (mwfull[N])
                    slave_awaccepts[N] = 1'b0;
                if (!wrequest[N][mwindex[N]])
                    slave_awaccepts[N] = 1'b0;
                if (!wgrant[N][NS])
                begin
                    if (!slave_awready[mwindex[N]])
                        slave_awaccepts[N] = 1'b0;
                end else if (berr_valid[N] && !bskd_ready[N])
                begin
                    slave_awaccepts[N] = 1'b0;
                end
            end

            // slave_waccepts
            always @(*) begin
                slave_waccepts[N] = 1'b1;
                if (!mwgrant[N])
                    slave_waccepts[N] = 1'b0;
                if (!wdata_expected[N] && (!OPT_AWW || !slave_awaccepts[N]))
                    slave_waccepts[N] = 1'b0;
                if (!wgrant[N][NS])
                begin
                    if (!slave_wready[mwindex[N]])
                        slave_waccepts[N] = 1'b0;
                end else if (berr_valid[N] && !bskd_ready[N])
                    slave_waccepts[N] = 1'b0;
            end

		    reg	r_awvalid;

            always @(*) begin
                r_awvalid = dcd_awvalid[N] && !mwfull[N];
                wrequest[N]= 0;
                if (!mwfull[N])
                    wrequest[N][NS:0] = wdecode;
            end

            assign	m_awvalid[N] = r_awvalid;



	    end 
        for (N=NM; N<NMFULL; N=N+1) begin : UNUSED_WSKID_BUFFERS
            assign	m_awid[N]    = 0;
            assign	m_awaddr[N]  = 0;
            assign	m_awlen[N]   = 0;
            assign	m_awsize[N]  = 0;
            assign	m_awburst[N] = 0;
            assign	m_awlock[N]  = 0;
            assign	m_awcache[N] = 0;
            assign	m_awprot[N]  = 0;
            assign	m_awqos[N]   = 0;

            assign	m_awvalid[N] = 0;

            assign	m_wvalid[N]  = 0;
            assign	m_wdata[N] = 0;
            assign	m_wstrb[N] = 0;
            assign	m_wlast[N] = 0;

        end 
    endgenerate

    // Read skid buffers and address decoding, slave_araccepts logic
    generate for(N=0; N<NM; N=N+1) begin : R1_DECODE_READ_REQUEST
        reg		r_arvalid;
        wire	[NS:0]	rdecode;

        axi_w_addr_skid_buffer #(
            .REGISTER_OUTPUT(OPT_SKID_INPUT),
            .ADDR_WIDTH(ADDR_WIDTH),
            .ID_WIDTH(ID_WIDTH)
        ) arskid (
            .clock(clock),
            .reset(reset),
            .in_valid(slaves[N].ARVALID),
            .in_ready(slaves[N].ARREADY),
            .in_id(slaves[N].ARID),
            .in_addr(slaves[N].ARADDR),
            .in_len(slaves[N].ARLEN),
            .in_size(slaves[N].ARSIZE),
            .in_burst(slaves[N].ARBURST),
            .in_lock(slaves[N].ARLOCK),
            .in_cache(slaves[N].ARCACHE),
            .in_prot(slaves[N].ARPROT),
            .in_qos(slaves[N].ARQOS),
                                
            .out_valid(skd_arvalid[N]),
            .out_ready(!skd_arstall[N]),

            .out_id(skd_arid[N]),
            .out_addr(skd_araddr[N]),
            .out_len(skd_arlen[N]),
            .out_size(skd_arsize[N]),
            .out_burst(skd_arburst[N]),
            .out_lock(skd_arlock[N]),
            .out_cache(skd_arcache[N]),
            .out_prot(skd_arprot[N]),
            .out_qos(skd_arqos[N])
        );


        axi_address_decoder #(
            .AW(ADDR_WIDTH),
            .IW(ID_WIDTH),
            .NS(NS),
            .SLAVE_ADDR(SLAVE_ADDR),
            .SLAVE_MASK(SLAVE_MASK),
            .OPT_REGISTERED(OPT_BUFFER_DECODER),
            .OPT_LOWPOWER(OPT_LOWPOWER)
        ) rdaddr (
            .clock(clock),
            .reset(reset),
            .i_valid(skd_arvalid[N]),
            .o_stall(skd_arstall[N]),
            .i_addr(skd_araddr[N]),
            .i_id(skd_arid[N]),
            .i_len(skd_arlen[N]),
            .i_size(skd_arsize[N]),
            .i_burst(skd_arburst[N]),
            .i_lock(skd_arlock[N]),
            .i_cache(skd_arcache[N]),
            .i_prot(skd_arprot[N]),
            .i_qos(skd_arqos[N]),
            .o_valid(dcd_arvalid[N]),
            .i_stall(!m_arvalid[N] || !slave_raccepts[N]),
            .o_decode(rdecode),
            .o_addr(m_araddr[N]),
            .o_id(m_arid[N]),
            .o_len(m_arlen[N]),
            .o_size(m_arsize[N]),
            .o_burst(m_arburst[N]),
            .o_lock(m_arlock[N]),
            .o_cache(m_arcache[N]),
            .o_prot(m_arprot[N]),
            .o_qos(m_arqos[N])
        );


        always @(*) begin
            r_arvalid = dcd_arvalid[N] && !mrfull[N];
            rrequest[N] = 0;
            if (!mrfull[N])
                rrequest[N][NS:0] = rdecode;
        end

        assign	m_arvalid[N] = r_arvalid;

        // slave_raccepts decoding
        always @(*) begin
            slave_raccepts[N] = 1'b1;
            if (!mrgrant[N])
                slave_raccepts[N] = 1'b0;
            if (mrfull[N])
                slave_raccepts[N] = 1'b0;
            if (!rrequest[N][mrindex[N]])
                slave_raccepts[N] = 1'b0;
            if (!rgrant[N][NS])
            begin
                if (!slave_arready[mrindex[N]])
                    slave_raccepts[N] = 1'b0;
            end else if (!mrempty[N] || !rerr_none[N] || rskd_valid[N])
                slave_raccepts[N] = 1'b0;
        end


	    end 
        for (N=NM; N<NMFULL; N=N+1) begin : UNUSED_RSKID_BUFFERS
            assign	m_arvalid[N] = 0;
            assign	m_arid[N]    = 0;
            assign	m_araddr[N]  = 0;
            assign	m_arlen[N]   = 0;
            assign	m_arsize[N]  = 0;
            assign	m_arburst[N] = 0;
            assign	m_arlock[N]  = 0;
            assign	m_arcache[N] = 0;
            assign	m_arprot[N]  = 0;
            assign	m_arqos[N]   = 0;

        end 
    endgenerate

    ////////////////////////////////////////////////////////////////////////
    // Channel arbitration
    ////////////////////////////////////////////////////////////////////////

    // wrequested
    always @(*) begin : W2_DECONFLICT_WRITE_REQUESTS

        for(iN=0; iN<=NM; iN=iN+1)
            wrequested[iN] = 0;

        wrequested[NM] = 0;

        for(iM=0; iM<NS; iM=iM+1) begin
            wrequested[0][iM] = 1'b0;
            for(iN=1; iN<NM ; iN=iN+1) begin
                if (wrequest[iN-1][iM] && wgrant[iN-1][iM])
                    wrequested[iN][iM] = 1;
                if (wrequest[iN-1][iM] && (!mwgrant[iN-1]||mwempty[iN-1]))
                    wrequested[iN][iM] = 1;
                if (wrequested[iN-1][iM])
                    wrequested[iN][iM] = 1;
            end
            wrequested[NM][iM] = wrequest[NM-1][iM] || wrequested[NM-1][iM];
        end
    end

    // rrequested
    always @(*) begin : R2_DECONFLICT_READ_REQUESTS

        for(iN=0; iN<NM ; iN=iN+1)
            rrequested[iN] = 0;

        rrequested[NM] = 0;

        for(iM=0; iM<NS; iM=iM+1) begin
            rrequested[0][iM] = 0;
            for(iN=1; iN<NM ; iN=iN+1) begin
                if (rrequest[iN-1][iM] && rgrant[iN-1][iM])
                    rrequested[iN][iM] = 1;
                if (rrequest[iN-1][iM] && (!mrgrant[iN-1] || mrempty[iN-1]))
                    rrequested[iN][iM] = 1;
                if (rrequested[iN-1][iM])
                    rrequested[iN][iM] = 1;
            end
            rrequested[NM][iM] = rrequest[NM-1][iM] || rrequested[NM-1][iM];
        end
    end


	generate 
        for(N=0; N<NM; N=N+1) begin : W3_ARBITRATE_WRITE_REQUESTS
            reg			stay_on_channel;
            reg			requested_channel_is_available;
            reg			leave_channel;
            reg	[LGNS-1:0]	requested_index;
            wire			linger;
            reg	[LGNS-1:0]	r_mwindex;

            // stay_on_channel
            always @(*) begin
                stay_on_channel = |(wrequest[N][NS:0] & wgrant[N]);

                if (mwgrant[N] && !mwempty[N])
                    stay_on_channel = 1;

                if (berr_valid[N])
                    stay_on_channel = 1;
            end

            // requested_channel_is_available
            always @(*) begin
                requested_channel_is_available =
                    |(wrequest[N][NS-1:0] & ~swgrant
                            & ~wrequested[N][NS-1:0]);
                            
                if (wrequest[N][NS])
                    requested_channel_is_available = 1;

                if (NM < 2)
                    requested_channel_is_available = m_awvalid[N];
            end

            // Linger option, and setting the "linger" flag
            if (OPT_LINGER == 0) begin
                assign	linger = 0;
            end else begin : WRITE_LINGER

                reg [LGLINGER-1:0]	linger_counter;
                reg			r_linger;

                initial	r_linger = 0;
                initial	linger_counter = 0;
                always @(posedge clock)
                if (!reset || wgrant[N][NS])
                begin
                    r_linger <= 0;
                    linger_counter <= 0;
                end else if (!mwempty[N] || bskd_valid[N])
                begin
                    linger_counter <= OPT_LINGER;
                    r_linger <= 1;
                end else if (linger_counter > 0)
                begin
                    r_linger <= (linger_counter > 1);
                    linger_counter <= linger_counter - 1;
                end else
                    r_linger <= 0;

                assign	linger = r_linger;
            end

            // leave_channel
            always @(*) begin
                leave_channel = 0;
                if (!m_awvalid[N]
                    && (!linger || wrequested[NM][mwindex[N]]))
                    leave_channel = 1;
                if (m_awvalid[N] && !wrequest[N][mwindex[N]])
                    leave_channel = 1;
            end

            // WRITE GRANT ALLOCATION
            always @(posedge clock)
            if (!reset) begin
                wgrant[N]  <= 0;
                mwgrant[N] <= 0;
            end else if (!stay_on_channel)begin
                if (requested_channel_is_available) begin
                    // Switch to a new channel
                    mwgrant[N] <= 1'b1;
                    wgrant[N]  <= wrequest[N][NS:0];
                end else if (leave_channel) begin
                    // Revoke the given grant
                    mwgrant[N] <= 1'b0;
                    wgrant[N]  <= 0;
                end
            end

            // mwindex (registered)
            always @(wrequest[N]) begin
                requested_index = 0;
                for(iM=0; iM<=NS; iM=iM+1)
                if (wrequest[N][iM])
                    requested_index= requested_index | iM[LGNS-1:0];
            end

            // Now for mwindex
            initial	r_mwindex = 0;
            always @(posedge clock)
            if (!stay_on_channel && requested_channel_is_available)
                r_mwindex <= requested_index;

            assign	mwindex[N] = r_mwindex;

        end
        for (N=NM; N<NMFULL; N=N+1) begin

            assign	mwindex[N] = 0;
        end 
    endgenerate

	generate 
        for(N=0; N<NM; N=N+1) begin : R3_ARBITRATE_READ_REQUESTS
            reg			stay_on_channel;
            reg			requested_channel_is_available;
            reg			leave_channel;
            reg	[LGNS-1:0]	requested_index;
            reg			linger;
            reg	[LGNS-1:0]	r_mrindex;


            always @(*) begin
                stay_on_channel = |(rrequest[N][NS:0] & rgrant[N]);

                if (mrgrant[N] && !mrempty[N])
                    stay_on_channel = 1;

                if (rgrant[N][NS] && (!rerr_none[N] || rskd_valid[N]))
                    stay_on_channel = 1;
            end

            // requested_channel_is_available
            always @(*) begin
                
                requested_channel_is_available =
                    |(rrequest[N][NS-1:0] & ~srgrant
                            & ~rrequested[N][NS-1:0]);

                if (rrequest[N][NS])
                    requested_channel_is_available = 1;

                if (NM < 2)
                    requested_channel_is_available = m_arvalid[N];
            end

            // Linger option, and setting the "linger" flag
            if (OPT_LINGER == 0)
            begin
                always @(*)
                    linger = 0;
            end else begin : READ_LINGER

                reg [LGLINGER-1:0]	linger_counter;

                initial	linger = 0;
                initial	linger_counter = 0;

                always @(posedge clock)
                if (!reset || rgrant[N][NS]) begin
                    linger <= 0;
                    linger_counter <= 0;
                end else if (!mrempty[N] || rskd_valid[N]) begin
                    linger_counter <= OPT_LINGER;
                    linger <= 1;
                end else if (linger_counter > 0) begin
                    linger <= (linger_counter > 1);
                    linger_counter <= linger_counter - 1;
                end else
                    linger <= 0;

            end

            // leave_channel
            always @(*) begin
                leave_channel = 0;
                if (!m_arvalid[N]
                    && (!linger || rrequested[NM][mrindex[N]]))
                    // Leave the channel after OPT_LINGER counts
                    // of the channel being idle, or when someone
                    // else asks for the channel
                    leave_channel = 1;
                if (m_arvalid[N] && !rrequest[N][mrindex[N]])
                    // Need to leave this channel to connect
                    // to any other channel
                    leave_channel = 1;
            end


            // READ GRANT ALLOCATION
            always @(posedge clock)
            if (!reset) begin
                rgrant[N]  <= 0;
                mrgrant[N] <= 0;
            end else if (!stay_on_channel) begin
                if (requested_channel_is_available) begin
                    // Switching channels
                    mrgrant[N] <= 1'b1;
                    rgrant[N] <= rrequest[N][NS:0];
                end else if (leave_channel) begin
                    mrgrant[N] <= 1'b0;
                    rgrant[N]  <= 0;
                end
            end

            // mrindex (registered)
            always @(rrequest[N]) begin
                requested_index = 0;
                for(iM=0; iM<=NS; iM=iM+1)
                if (rrequest[N][iM])
                    requested_index = requested_index|iM[LGNS-1:0];
            end

            initial	r_mrindex = 0;
            always @(posedge clock)
            if (!stay_on_channel && requested_channel_is_available)
                r_mrindex <= requested_index;

            assign	mrindex[N] = r_mrindex;

        end for (N=NM; N<NMFULL; N=N+1) begin
            assign	mrindex[N] = 0;
        end
    endgenerate

	// Calculate swindex (registered)
	generate 
        for (M=0; M<NS; M=M+1) begin : W4_SLAVE_WRITE_INDEX
            if (NM <= 1) begin

                assign	swindex[M] = 0;

            end else begin : MULTIPLE_MASTERS

                reg [LGNM-1:0]	reqwindex, r_swindex;

                always @(*) begin
                    reqwindex = 0;
                for(iN=0; iN<NM; iN=iN+1)
                if ((!mwgrant[iN] || mwempty[iN])
                    &&(wrequest[iN][M] && !wrequested[iN][M]))
                        reqwindex = reqwindex | iN[LGNM-1:0];
                end

                always @(posedge clock)
                if (!swgrant[M])
                    r_swindex <= reqwindex;

                assign	swindex[M] = r_swindex;
            end

        end for (M=NS; M<NSFULL; M=M+1) begin

            assign	swindex[M] = 0;
        end
    endgenerate

    // Calculate srindex (registered)
    generate 
        for (M=0; M<NS; M=M+1) begin : R4_SLAVE_READ_INDEX

            if (NM <= 1) begin
                assign	srindex[M] = 0;

            end else begin : MULTIPLE_MASTERS

                reg [LGNM-1:0]	reqrindex, r_srindex;

                always @(*) begin
                    reqrindex = 0;
                for(iN=0; iN<NM; iN=iN+1)
                if ((!mrgrant[iN] || mrempty[iN])
                    &&(rrequest[iN][M] && !rrequested[iN][M]))
                        reqrindex = reqrindex | iN[LGNM-1:0];
                end

                always @(posedge clock)
                if (!srgrant[M])
                    r_srindex <= reqrindex;

                assign	srindex[M] = r_srindex;
            end

        end 
        for (M=NS; M<NSFULL; M=M+1)begin
            assign	srindex[M] = 0;
        end 
    endgenerate

	// swgrant and srgrant (combinatorial)
    generate 
        for(M=0; M<NS; M=M+1) begin : SGRANT

            // swgrant: write arbitration
            initial	swgrant = 0;
            always @(*) begin
                swgrant[M] = 0;
                for(iN=0; iN<NM; iN=iN+1)
                if (wgrant[iN][M])
                    swgrant[M] = 1;
            end

            initial	srgrant = 0;
            // srgrant: read arbitration
            always @(*) begin
                srgrant[M] = 0;
                for(iN=0; iN<NM; iN=iN+1)
                if (rgrant[iN][M])
                    srgrant[M] = 1;
            end
        end 
    endgenerate

    ////////////////////////////////////////////////////////////////////////
    // Generate the signals for the various slaves--the forward channel
    ////////////////////////////////////////////////////////////////////////

    // Assign outputs to the various slaves
    generate 
        for(M=0; M<NS; M=M+1) begin : W5_WRITE_SLAVE_OUTPUTS
            reg			axi_awvalid;
            reg	[ID_WIDTH-1:0]	axi_awid;
            reg	[ADDR_WIDTH-1:0]	axi_awaddr;
            reg	[7:0]		axi_awlen;
            reg	[2:0]		axi_awsize;
            reg	[1:0]		axi_awburst;
            reg			axi_awlock;
            reg	[3:0]		axi_awcache;
            reg	[2:0]		axi_awprot;
            reg	[3:0]		axi_awqos;

            reg			axi_wvalid;
            reg	[DATA_WIDTH-1:0]	axi_wdata;
            reg	[DATA_WIDTH/8-1:0]	axi_wstrb;
            reg			axi_wlast;
            //
            reg			axi_bready;

            reg			sawstall, swstall;
            reg			awaccepts;

            // Control the slave's AW* channel
            // Personalize the slave_awaccepts signal
            always @(*)
                awaccepts = slave_awaccepts[swindex[M]];

            always @(*)
                sawstall= (masters[M].AWVALID && !masters[M].AWREADY);

            initial	axi_awvalid = 0;
            always @(posedge  clock)
            if (!reset || !swgrant[M])
                axi_awvalid <= 0;
            else if (!sawstall) begin
                axi_awvalid <= m_awvalid[swindex[M]] &&(awaccepts);
            end

            initial	axi_awid    = 0;
            initial	axi_awaddr  = 0;
            initial	axi_awlen   = 0;
            initial	axi_awsize  = 0;
            initial	axi_awburst = 0;
            initial	axi_awlock  = 0;
            initial	axi_awcache = 0;
            initial	axi_awprot  = 0;
            initial	axi_awqos   = 0;
            always @(posedge  clock)
            if (OPT_LOWPOWER && (!reset || !swgrant[M])) begin
                // Under the OPT_LOWPOWER option, we clear all signals
                // we aren't using
                axi_awid    <= 0;
                axi_awaddr  <= 0;
                axi_awlen   <= 0;
                axi_awsize  <= 0;
                axi_awburst <= 0;
                axi_awlock  <= 0;
                axi_awcache <= 0;
                axi_awprot  <= 0;
                axi_awqos   <= 0;
            end else if (!sawstall) begin
                if (!OPT_LOWPOWER||(m_awvalid[swindex[M]]&&awaccepts)) begin
                    // swindex[M] is defined as 0 above in the
                    // case where NM <= 1
                    axi_awid    <= m_awid[   swindex[M]];
                    axi_awaddr  <= m_awaddr[ swindex[M]];
                    axi_awlen   <= m_awlen[  swindex[M]];
                    axi_awsize  <= m_awsize[ swindex[M]];
                    axi_awburst <= m_awburst[swindex[M]];
                    axi_awlock  <= m_awlock[ swindex[M]];
                    axi_awcache <= m_awcache[swindex[M]];
                    axi_awprot  <= m_awprot[ swindex[M]];
                    axi_awqos   <= m_awqos[  swindex[M]];
                end else begin
                    axi_awid    <= 0;
                    axi_awaddr  <= 0;
                    axi_awlen   <= 0;
                    axi_awsize  <= 0;
                    axi_awburst <= 0;
                    axi_awlock  <= 0;
                    axi_awcache <= 0;
                    axi_awprot  <= 0;
                    axi_awqos   <= 0;
                end
            end

            // Control the slave's W* channel
            always @(*)
                swstall = (masters[M].WVALID && !masters[M].WREADY);

            initial	axi_wvalid = 0;
            always @(posedge clock)
            if (!reset || !swgrant[M])
                axi_wvalid <= 0;
            else if (!swstall) begin
                axi_wvalid <= (m_wvalid[swindex[M]])
                        &&(slave_waccepts[swindex[M]]);
            end

            initial axi_wdata  = 0;
            initial axi_wstrb  = 0;
            initial axi_wlast  = 0;
            always @(posedge clock)
            if (OPT_LOWPOWER && !reset) begin
                axi_wdata  <= 0;
                axi_wstrb  <= 0;
                axi_wlast  <= 0;
            end else if (OPT_LOWPOWER && !swgrant[M]) begin
                axi_wdata  <= 0;
                axi_wstrb  <= 0;
                axi_wlast  <= 0;
            end else if (!swstall) begin
                if (!OPT_LOWPOWER || (m_wvalid[swindex[M]]&&slave_waccepts[swindex[M]])) begin
                    // If NM <= 1, swindex[M] is already defined
                    // to be zero above
                    axi_wdata  <= m_wdata[swindex[M]];
                    axi_wstrb  <= m_wstrb[swindex[M]];
                    axi_wlast  <= m_wlast[swindex[M]];
                end else begin
                    axi_wdata  <= 0;
                    axi_wstrb  <= 0;
                    axi_wlast  <= 0;
                end
            end

            //
            always @(*)
            if (!swgrant[M])
                axi_bready = 1;
            else
                axi_bready = bskd_ready[swindex[M]];

            // Combinatorial assigns
            assign	masters[M].AWVALID          = axi_awvalid;
            assign	masters[M].AWID = axi_awid;
            assign	masters[M].AWADDR = axi_awaddr;
            assign	masters[M].AWLEN = axi_awlen;
            assign	masters[M].AWSIZE = axi_awsize;
            assign	masters[M].AWBURST = axi_awburst;
            assign	masters[M].AWLOCK         = axi_awlock;
            assign	masters[M].AWCACHE = axi_awcache;
            assign	masters[M].AWPROT = axi_awprot;
            assign	masters[M].AWQOS = axi_awqos;
            //
            //
            assign	masters[M].WVALID             = axi_wvalid;
            assign	masters[M].WDATA     = axi_wdata;
            assign	masters[M].WSTRB = axi_wstrb;
            assign	masters[M].WLAST              = axi_wlast;
            //
            //
            assign	masters[M].BREADY             = axi_bready;
            
        end 
    endgenerate


    generate 
        for(M=0; M<NS; M=M+1) begin : R5_READ_SLAVE_OUTPUTS
            reg				axi_arvalid;
            reg	[ID_WIDTH-1:0]		axi_arid;
            reg	[ADDR_WIDTH-1:0]		axi_araddr;
            reg	[7:0]			axi_arlen;
            reg	[2:0]			axi_arsize;
            reg	[1:0]			axi_arburst;
            reg				axi_arlock;
            reg	[3:0]			axi_arcache;
            reg	[2:0]			axi_arprot;
            reg	[3:0]			axi_arqos;
            //
            reg				axi_rready;
            reg				arstall;

            always @(*)
                arstall= axi_arvalid && !masters[M].ARREADY;

            initial	axi_arvalid = 0;
            always @(posedge  clock)
            if (!reset || !srgrant[M])
                axi_arvalid <= 0;
            else if (!arstall)
                axi_arvalid <= m_arvalid[srindex[M]] && slave_raccepts[srindex[M]];
            else if (masters[M].ARREADY)
                axi_arvalid <= 0;

            initial axi_arid    = 0;
            initial axi_araddr  = 0;
            initial axi_arlen   = 0;
            initial axi_arsize  = 0;
            initial axi_arburst = 0;
            initial axi_arlock  = 0;
            initial axi_arcache = 0;
            initial axi_arprot  = 0;
            initial axi_arqos   = 0;
            always @(posedge  clock)
            if (OPT_LOWPOWER && (!reset || !srgrant[M])) begin
                axi_arid    <= 0;
                axi_araddr  <= 0;
                axi_arlen   <= 0;
                axi_arsize  <= 0;
                axi_arburst <= 0;
                axi_arlock  <= 0;
                axi_arcache <= 0;
                axi_arprot  <= 0;
                axi_arqos   <= 0;
            end else if (!arstall) begin
                if (!OPT_LOWPOWER || (m_arvalid[srindex[M]] && slave_raccepts[srindex[M]])) begin
                    // If NM <=1, srindex[M] is defined to be zero
                    axi_arid    <= m_arid[   srindex[M]];
                    axi_araddr  <= m_araddr[ srindex[M]];
                    axi_arlen   <= m_arlen[  srindex[M]];
                    axi_arsize  <= m_arsize[ srindex[M]];
                    axi_arburst <= m_arburst[srindex[M]];
                    axi_arlock  <= m_arlock[ srindex[M]];
                    axi_arcache <= m_arcache[srindex[M]];
                    axi_arprot  <= m_arprot[ srindex[M]];
                    axi_arqos   <= m_arqos[  srindex[M]];
                end else begin
                    axi_arid    <= 0;
                    axi_araddr  <= 0;
                    axi_arlen   <= 0;
                    axi_arsize  <= 0;
                    axi_arburst <= 0;
                    axi_arlock  <= 0;
                    axi_arcache <= 0;
                    axi_arprot  <= 0;
                    axi_arqos   <= 0;
                end
            end

            always @(*)
            if (!srgrant[M])
                axi_rready = 1;
            else
                axi_rready = rskd_ready[srindex[M]];

            //
            assign	masters[M].ARVALID          = axi_arvalid;
            assign	masters[M].ARID = axi_arid;
            assign	masters[M].ARADDR = axi_araddr;
            assign	masters[M].ARLEN = axi_arlen;
            assign	masters[M].ARSIZE = axi_arsize;
            assign	masters[M].ARBURST = axi_arburst;
            assign	masters[M].ARLOCK          = axi_arlock;
            assign	masters[M].ARCACHE = axi_arcache;
            assign	masters[M].ARPROT = axi_arprot;
            assign	masters[M].ARQOS = axi_arqos;
            //
            assign	masters[M].RREADY        = axi_rready;
            //
        end 
    endgenerate

    ////////////////////////////////////////////////////////////////////////
    // Generate the signals for the various masters--the return channel
    ////////////////////////////////////////////////////////////////////////

    // Return values
	generate 
        for (N=0; N<NM; N=N+1)begin : W6_WRITE_RETURN_CHANNEL
            reg	[1:0]	i_axi_bresp;
            reg	[ID_WIDTH-1:0] i_axi_bid;

            // Write error (no slave selected) state machine
            always @(posedge clock)
            if (!reset)
                berr_valid[N] <= 0;
            else if (wgrant[N][NS] && m_wvalid[N] && m_wlast[N]
                    && slave_waccepts[N])
                berr_valid[N] <= 1;
            else if (bskd_ready[N])
                berr_valid[N] <= 0;

            always @(*)
            if (berr_valid[N])
                bskd_valid[N] = 1;
            else
                bskd_valid[N] = mwgrant[N]&&m_axi_bvalid[mwindex[N]];

            always @(posedge clock)
            if (m_awvalid[N] && slave_awaccepts[N])
                berr_id[N] <= m_awid[N];

            always @(*)
            if (wgrant[N][NS])
            begin
                i_axi_bid   = berr_id[N];
                i_axi_bresp = INTERCONNECT_ERROR;
            end else begin
                i_axi_bid   = m_axi_bid[mwindex[N]];
                i_axi_bresp = m_axi_bresp[mwindex[N]];
            end


        axi_w_resp_skid_buffer #(
            .ID_WIDTH(ID_WIDTH),
            .REGISTER_OUTPUT(1)
        ) bskid (
            .clock(clock),
            .reset(reset),
            .in_valid(bskd_valid[N]),
            .in_ready(bskd_ready[N]),
            .in_id(i_axi_bid),
            .in_resp(i_axi_bresp),
            .out_valid(slaves[N].BVALID),
            .out_ready(slaves[N].BREADY),
            .out_id(slaves[N].BID),
            .out_resp(slaves[N].BRESP)

        );


        end
    endgenerate

	// Return values
	generate for (N=0; N<NM; N=N+1)
        begin : R6_READ_RETURN_CHANNEL

            reg	[DATA_WIDTH-1:0]	i_axi_rdata;
            reg	[ID_WIDTH-1:0]	i_axi_rid;
            reg	[2-1:0]		i_axi_rresp;

            // generate the read response
            always @(*)
            if (rgrant[N][NS])
                rskd_valid[N] = !rerr_none[N];
            else
                rskd_valid[N] = mrgrant[N] && m_axi_rvalid[mrindex[N]];

            always @(*)
            if (rgrant[N][NS]) begin
                i_axi_rid   = rerr_id[N];
                i_axi_rdata = 0;
                rskd_rlast[N] = rerr_last[N];
                i_axi_rresp = INTERCONNECT_ERROR;
            end else begin
                i_axi_rid   = m_axi_rid[mrindex[N]];
                i_axi_rdata = m_axi_rdata[mrindex[N]];
                rskd_rlast[N]= m_axi_rlast[mrindex[N]];
                i_axi_rresp = m_axi_rresp[mrindex[N]];
            end


            axi_r_data_skid_buffer #(
                .REGISTER_OUTPUT(1),
                .DATA_WIDTH(DATA_WIDTH),
                .ID_WIDTH(ID_WIDTH)
            ) rskid (
                .clock(clock),
                .reset(reset),
                .in_valid(rskd_valid[N]),
                .in_ready(rskd_ready[N]),
                .in_data(i_axi_rdata),
                .in_id(i_axi_rid),
                .in_last(rskd_rlast[N]),
                .in_rresp(i_axi_rresp),
                .out_valid(slaves[N].RVALID),
                .out_ready(slaves[N].RREADY),
                .out_data(slaves[N].RDATA),
                .out_id(slaves[N].RID),
                .out_last(slaves[N].RLAST),
                .out_rresp(slaves[N].RRESP)

            );

          

        end 
    endgenerate
    ////////////////////////////////////////////////////////////////////////
    // Count pending transactions
    ////////////////////////////////////////////////////////////////////////


	generate
        for (N=0; N<NM; N=N+1) begin : W7_COUNT_PENDING_WRITES
        
            reg	[LGMAXBURST-1:0]	awpending, wpending;
            reg				r_wdata_expected;

            // awpending, and the associated flags mwempty and mwfull

            initial	awpending    = 0;
            always @(posedge clock)
            if (!reset) begin
                awpending     <= 0;
                mwempty[N]    <= 1;
                mwfull[N]     <= 0;
            end else case ({(m_awvalid[N] && slave_awaccepts[N]),
                    (bskd_valid[N] && bskd_ready[N])})
            2'b01: begin
                awpending     <= awpending - 1;
                mwempty[N]    <= (awpending <= 1);
                mwfull[N]     <= 0;
                end
            2'b10: begin
                awpending <= awpending + 1;
                mwempty[N] <= 0;
                mwfull[N]     <= &awpending[LGMAXBURST-1:1];
                end
            default: begin end
            endcase


            assign	w_mawpending[N] = awpending;

            // r_wdata_expected and wdata_expected  
            initial	r_wdata_expected = 0;
            initial	wpending = 0;
            always @(posedge clock)
            if (!reset) begin
                r_wdata_expected <= 0;
                wpending <= 0;
            end else case ({(m_awvalid[N] && slave_awaccepts[N]),
                    (m_wvalid[N]&&slave_waccepts[N] && m_wlast[N])})
            2'b01: begin
                r_wdata_expected <= (wpending > 1);
                wpending <= wpending - 1;
                end
            2'b10: begin
                wpending <= wpending + 1;
                r_wdata_expected <= 1;
                end
            default: begin end
            endcase

            assign	wdata_expected[N] = r_wdata_expected;

            assign wlasts_pending[N] = wpending;
        end 
    endgenerate

	generate
        for (N=0; N<NM; N=N+1) begin : R7_COUNT_PENDING_READS

            reg	[LGMAXBURST-1:0]	rpending;

            initial	rpending     = 0;
            always @(posedge clock)
            if (!reset) begin
                rpending  <= 0;
                mrempty[N]<= 1;
                mrfull[N] <= 0;
            end else case ({(m_arvalid[N] && slave_raccepts[N] && !rgrant[N][NS]),
                    (rskd_valid[N] && rskd_ready[N]
                        && rskd_rlast[N] && !rgrant[N][NS])})
            2'b01: begin
                rpending      <= rpending - 1;
                mrempty[N]    <= (rpending == 1);
                mrfull[N]     <= 0;
                end
            2'b10: begin
                rpending      <= rpending + 1;
                mrfull[N]     <= &rpending[LGMAXBURST-1:1];
                mrempty[N]    <= 0;
                end
            default: begin end
            endcase

            assign	w_mrpending[N]  = rpending;

            // Read error state machine, rerr_outstanding and rerr_id
            initial	rerr_outstanding[N] = 0;
            always @(posedge clock)
            if (!reset) begin
                rerr_outstanding[N] <= 0;
                rerr_last[N] <= 0;
                rerr_none[N] <= 1;
            end else if (!rerr_none[N]) begin
                if (!rskd_valid[N] || rskd_ready[N]) begin
                    rerr_none[N] <= (rerr_outstanding[N] == 1);
                    rerr_last[N] <= (rerr_outstanding[N] == 2);
                    rerr_outstanding[N] <= rerr_outstanding[N] - 1;
                end
            end else if (m_arvalid[N] && rrequest[N][NS]
                            && slave_raccepts[N]) begin
                rerr_none[N] <= 0;
                rerr_last[N] <= (m_arlen[N] == 0);
                rerr_outstanding[N] <= m_arlen[N] + 1;
            end

            // rerr_id is the ARID field of the currently outstanding
            // error.  It's used when generating a read response to a
            // non-existent slave.
            initial	rerr_id[N] = 0;
            always @(posedge clock)
            if (!reset && OPT_LOWPOWER)
                rerr_id[N] <= 0;
            else if (m_arvalid[N] && slave_raccepts[N]) begin
                if (rrequest[N][NS] || !OPT_LOWPOWER)
                    // A low-logic definition
                    rerr_id[N] <= m_arid[N];
                else
                    rerr_id[N] <= 0;
            end else if (OPT_LOWPOWER && rerr_last[N]
                    && (!rskd_valid[N] || rskd_ready[N]))
                rerr_id[N] <= 0;
        end 
    endgenerate
    

endmodule