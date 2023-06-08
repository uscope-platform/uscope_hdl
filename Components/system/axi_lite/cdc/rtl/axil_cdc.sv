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
`include "interfaces.svh"

module axil_cdc #(
    N_STAGES = 2,
    DATA_WIDTH = 32,
    ADDR_WIDTH = 32
)(
    input wire reset,
    input wire clock_in,
    input wire clock_out,
    axi_lite.slave in,
    axi_lite.master out
);

   xpm_fifo_axil #(
        .AXI_ADDR_WIDTH(ADDR_WIDTH),
        .AXI_DATA_WIDTH(DATA_WIDTH),
        .CDC_SYNC_STAGES(N_STAGES),
        .CLOCKING_MODE("independent_clock"),
        .EN_RESET_SYNCHRONIZER(1),
        .FIFO_DEPTH_RACH(16),
        .FIFO_DEPTH_RDCH(16),
        .FIFO_DEPTH_WACH(16),
        .FIFO_DEPTH_WDCH(16),
        .FIFO_DEPTH_WRCH(16),
        .USE_ADV_FEATURES_RDCH("0000"),
        .USE_ADV_FEATURES_WDCH("0000")
   )
   xpm_fifo_axil_inst (
        .s_aclk(clock_in),
        .s_aresetn(reset),
        .m_aclk(clock_out), 

        .m_axi_araddr(out.ARADDR),
        .m_axi_arprot(out.ARPROT),
        .m_axi_arvalid(out.ARVALID),
        .m_axi_awaddr(out.AWADDR),
        .m_axi_awprot(out.AWPROT),
        .m_axi_awvalid(out.AWVALID),
        .m_axi_bready(out.BREADY),
        .m_axi_rready(out.RREADY),
        .m_axi_wdata(out.WDATA),
        .m_axi_wstrb(out.WVALID),
        .m_axi_wvalid(out.WSTRB),

        .s_axi_arready(in.ARREADY),
        .s_axi_awready(in.AWREADY),
        .s_axi_bresp(in.BRESP),
        .s_axi_bvalid(in.BVALID),
        .s_axi_rdata(in.RDATA),
        .s_axi_rresp(in.RRESP),
        .s_axi_rvalid(in.RVALID),
        .s_axi_wready(in.WREADY),


        .m_axi_arready(out.ARREADY),
        .m_axi_awready(out.AWREADY),
        .m_axi_bresp(out.BRESP),
        .m_axi_bvalid(out.BVALID),
        .m_axi_rdata(out.RDATA),
        .m_axi_rresp(out.RRESP),
        .m_axi_rvalid(out.RVALID),
        .m_axi_wready(out.WREADY),

        .s_axi_araddr(in.ARADDR),
        .s_axi_arprot(in.ARPROT),
        .s_axi_arvalid(in.ARVALID),
        .s_axi_awaddr(in.AWADDR),
        .s_axi_awprot(in.AWPROT),
        .s_axi_awvalid(in.AWVALID),
        .s_axi_bready(in.BREADY),
        .s_axi_rready(in.RREADY),
        .s_axi_wdata(in.WDATA),
        .s_axi_wstrb(in.WVALID),
        .s_axi_wvalid(in.WSTRB)
   );


endmodule
