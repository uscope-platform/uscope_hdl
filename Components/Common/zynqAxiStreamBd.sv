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
`timescale 10 ns / 100 ps
`include "interfaces.svh"

module Zynq_axis_wrapper #(
    parameter FCORE_PRESENT = 0
) (
    APB.master APB,
    output wire IO_clock,
    output wire Logic_Clock,
    output wire [0:0]Reset,
    axi_lite.slave dma_axi,
    AXI.master fcore_axi,
    axi_stream.slave scope,
    output wire dma_done
  );
    

    AXI term();

    generate
        
        if(FCORE_PRESENT == 0)begin
            axi_terminator terminator(
                .clock(Logic_Clock),
                .reset(Reset),
                .axi(term)
            );


            PS_AXI_stream PS (
                .APB_M_0_paddr(APB.PADDR),
                .APB_M_0_penable(APB.PENABLE),
                .APB_M_0_pprot(APB.PPROT),
                .APB_M_0_prdata(APB.PRDATA),
                .APB_M_0_pready(APB.PREADY),
                .APB_M_0_psel(APB.PSEL),
                .APB_M_0_pslverr(APB.PSLVERR),
                .APB_M_0_pstrb(APB.PSTRB),
                .APB_M_0_pwdata(APB.PWDATA),
                .APB_M_0_pwrite(APB.PWRITE),
                .DDR_addr(DDR_addr),
                .DDR_ba(DDR_ba),
                .DDR_cas_n(DDR_cas_n),
                .DDR_ck_n(DDR_ck_n),
                .DDR_ck_p(DDR_ck_p),
                .DDR_cke(DDR_cke),
                .DDR_cs_n(DDR_cs_n),
                .DDR_dm(DDR_dm),
                .DDR_dq(DDR_dq),
                .DDR_dqs_n(DDR_dqs_n),
                .DDR_dqs_p(DDR_dqs_p),
                .DDR_odt(DDR_odt),
                .DDR_ras_n(DDR_ras_n),
                .DDR_reset_n(DDR_reset_n),
                .DDR_we_n(DDR_we_n),
                .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
                .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
                .FIXED_IO_mio(FIXED_IO_mio),
                .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
                .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
                .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
                .IO_clock(IO_clock),
                .Logic_Clock(Logic_Clock),
                .Reset(Reset),
                .dma_control_araddr(dma_axi.ARADDR),
                .dma_control_arready(dma_axi.ARREADY),
                .dma_control_arvalid(dma_axi.ARVALID),
                .dma_control_awaddr(dma_axi.AWADDR),
                .dma_control_awready(dma_axi.AWREADY),
                .dma_control_awvalid(dma_axi.AWVALID),
                .dma_control_bready(dma_axi.BREADY),
                .dma_control_bresp(dma_axi.BRESP),
                .dma_control_bvalid(dma_axi.BVALID),
                .dma_control_rdata(dma_axi.RDATA),
                .dma_control_rready(dma_axi.RREADY),
                .dma_control_rresp(dma_axi.RRESP),
                .dma_control_rvalid(dma_axi.RVALID),
                .dma_control_wdata(dma_axi.WDATA),
                .dma_control_wready(dma_axi.WREADY),
                .dma_control_wvalid(dma_axi.WVALID),
                .fCore_araddr(term.ARADDR),
                .fCore_arburst(term.ARBURST),
                .fCore_arlen(term.ARLEN),
                .fCore_arready(term.ARREADY),
                .fCore_arsize(term.ARSIZE),
                .fCore_arvalid(term.ARVALID),
                .fCore_awaddr(term.AWADDR),
                .fCore_awburst(term.AWBURST),
                .fCore_awlen(term.AWLEN),
                .fCore_awready(term.AWREADY),
                .fCore_awsize(term.AWSIZE),
                .fCore_awvalid(term.AWVALID),
                .fCore_bready(term.BREADY),
                .fCore_bresp(term.BRESP),
                .fCore_bvalid(term.BVALID),
                .fCore_rdata(term.RDATA),
                .fCore_rlast(term.RLAST),
                .fCore_rready(term.RREADY),
                .fCore_rresp(term.RRESP),
                .fCore_rvalid(term.RVALID),
                .fCore_wdata(term.WDATA),
                .fCore_wlast(term.WLAST),
                .fCore_wready(term.WREADY),
                .fCore_wstrb(term.WSTRB),
                .fCore_wvalid(term.WVALID),
                .scope_data_tdata(scope.data),
                .scope_data_tkeep(4'b1111),
                .scope_data_tlast(scope.tlast),
                .scope_data_tready(scope.ready),
                .scope_data_tvalid(scope.valid),
                .dma_done(dma_done)
            );
        end else begin
            
        PS_AXI_stream PS (
            .APB_M_0_paddr(APB.PADDR),
            .APB_M_0_penable(APB.PENABLE),
            .APB_M_0_pprot(APB.PPROT),
            .APB_M_0_prdata(APB.PRDATA),
            .APB_M_0_pready(APB.PREADY),
            .APB_M_0_psel(APB.PSEL),
            .APB_M_0_pslverr(APB.PSLVERR),
            .APB_M_0_pstrb(APB.PSTRB),
            .APB_M_0_pwdata(APB.PWDATA),
            .APB_M_0_pwrite(APB.PWRITE),
            .DDR_addr(DDR_addr),
            .DDR_ba(DDR_ba),
            .DDR_cas_n(DDR_cas_n),
            .DDR_ck_n(DDR_ck_n),
            .DDR_ck_p(DDR_ck_p),
            .DDR_cke(DDR_cke),
            .DDR_cs_n(DDR_cs_n),
            .DDR_dm(DDR_dm),
            .DDR_dq(DDR_dq),
            .DDR_dqs_n(DDR_dqs_n),
            .DDR_dqs_p(DDR_dqs_p),
            .DDR_odt(DDR_odt),
            .DDR_ras_n(DDR_ras_n),
            .DDR_reset_n(DDR_reset_n),
            .DDR_we_n(DDR_we_n),
            .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
            .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
            .FIXED_IO_mio(FIXED_IO_mio),
            .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
            .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
            .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
            .IO_clock(IO_clock),
            .Logic_Clock(Logic_Clock),
            .Reset(Reset),
            .dma_control_araddr(dma_axi.ARADDR),
            .dma_control_arready(dma_axi.ARREADY),
            .dma_control_arvalid(dma_axi.ARVALID),
            .dma_control_awaddr(dma_axi.AWADDR),
            .dma_control_awready(dma_axi.AWREADY),
            .dma_control_awvalid(dma_axi.AWVALID),
            .dma_control_bready(dma_axi.BREADY),
            .dma_control_bresp(dma_axi.BRESP),
            .dma_control_bvalid(dma_axi.BVALID),
            .dma_control_rdata(dma_axi.RDATA),
            .dma_control_rready(dma_axi.RREADY),
            .dma_control_rresp(dma_axi.RRESP),
            .dma_control_rvalid(dma_axi.RVALID),
            .dma_control_wdata(dma_axi.WDATA),
            .dma_control_wready(dma_axi.WREADY),
            .dma_control_wvalid(dma_axi.WVALID),
            .fCore_araddr(fcore_axi.ARADDR),
            .fCore_arburst(fcore_axi.ARBURST),
            .fCore_arlen(fcore_axi.ARLEN),
            .fCore_arready(fcore_axi.ARREADY),
            .fCore_arsize(fcore_axi.ARSIZE),
            .fCore_arvalid(fcore_axi.ARVALID),
            .fCore_awaddr(fcore_axi.AWADDR),
            .fCore_awburst(fcore_axi.AWBURST),
            .fCore_awlen(fcore_axi.AWLEN),
            .fCore_awready(fcore_axi.AWREADY),
            .fCore_awsize(fcore_axi.AWSIZE),
            .fCore_awvalid(fcore_axi.AWVALID),
            .fCore_bready(fcore_axi.BREADY),
            .fCore_bresp(fcore_axi.BRESP),
            .fCore_bvalid(fcore_axi.BVALID),
            .fCore_rdata(fcore_axi.RDATA),
            .fCore_rlast(fcore_axi.RLAST),
            .fCore_rready(fcore_axi.RREADY),
            .fCore_rresp(fcore_axi.RRESP),
            .fCore_rvalid(fcore_axi.RVALID),
            .fCore_wdata(fcore_axi.WDATA),
            .fCore_wlast(fcore_axi.WLAST),
            .fCore_wready(fcore_axi.WREADY),
            .fCore_wstrb(fcore_axi.WSTRB),
            .fCore_wvalid(fcore_axi.WVALID),
            .scope_data_tdata(scope.data),
            .scope_data_tkeep(4'b1111),
            .scope_data_tlast(scope.tlast),
            .scope_data_tready(scope.ready),
            .scope_data_tvalid(scope.valid),
            .dma_done(dma_done)
        );
        end

        
    endgenerate

endmodule