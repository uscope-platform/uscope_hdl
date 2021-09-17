//Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2018.2.2 (win64) Build 2348494 Mon Oct  1 18:25:44 MDT 2018
//Date        : Fri Oct 12 10:58:47 2018
//Host        : PMB119-7050-GB running 64-bit major release  (build 9200)
//Command     : generate_target zynq_apb_bd.bd
//Design      : zynq_apb_bd
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 10 ns / 1 ps
`include "interfaces.svh"

module Zynq_wrapper(
    APB.master APB,
    inout wire DDR_addr,
    inout wire DDR_ba,
    inout wire DDR_cas_n,
    inout wire DDR_ck_n,
    inout wire DDR_ck_p,
    inout wire DDR_cke,
    inout wire DDR_cs_n,
    inout wire DDR_dm,
    inout wire DDR_dq,
    inout wire DDR_dqs_n,
    inout wire DDR_dqs_p,
    inout wire DDR_odt,
    inout wire DDR_ras_n,
    inout wire DDR_reset_n,
    inout wire DDR_we_n,
    inout wire FIXED_IO_ddr_vrn,
    inout wire FIXED_IO_ddr_vrp,
    inout wire FIXED_IO_mio,
    inout wire FIXED_IO_ps_clk,
    inout wire FIXED_IO_ps_porb,
    inout wire FIXED_IO_ps_srstb,
    output wire Reset,
    output wire logic_clock,
    output wire IO_clock
);
    
  zynq_apb_bd zynq_apb_bd_i
       (.APB_M_0_paddr(APB.PADDR),
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
        .Logic_Clock(logic_clock),
        .IO_clock(IO_clock),
        .Reset(Reset)
    );
endmodule
