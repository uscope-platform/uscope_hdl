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

module kd240_ps #(
    parameter int FCORE_PRESENT = 0
) (
    output wire io_clock,
    output wire logic_clock,
    output wire [0:0]reset,
    axi_lite.master axi_out,
    AXI.master fcore_axi,
    AXI.slave scope,
    input wire dma_done
  );


    AXI term();

    generate

        if(FCORE_PRESENT == 0)begin
            axi_terminator terminator(
                .clock(logic_clock),
                .reset(reset),
                .axi(term)
            );


            ps PS (
                .IO_clock(io_clock),
                .logic_clock(logic_clock),
                .reset(reset),
                .axi_out_araddr(axi_out.ARADDR),
                .axi_out_arprot(axi_out.ARPROT),
                .axi_out_arready(axi_out.ARREADY),
                .axi_out_arvalid(axi_out.ARVALID),
                .axi_out_awaddr(axi_out.AWADDR),
                .axi_out_awprot(axi_out.AWPROT),
                .axi_out_awready(axi_out.AWREADY),
                .axi_out_awvalid(axi_out.AWVALID),
                .axi_out_bready(axi_out.BREADY),
                .axi_out_bresp(axi_out.BRESP),
                .axi_out_bvalid(axi_out.BVALID),
                .axi_out_rdata(axi_out.RDATA),
                .axi_out_rready(axi_out.RREADY),
                .axi_out_rresp(axi_out.RRESP),
                .axi_out_rvalid(axi_out.RVALID),
                .axi_out_wdata(axi_out.WDATA),
                .axi_out_wready(axi_out.WREADY),
                .axi_out_wstrb(axi_out.WSTRB),
                .axi_out_wvalid(axi_out.WVALID),
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
                .scope_data_awaddr(scope.AWADDR),
                .scope_data_awprot(scope.AWPROT),
                .scope_data_awready(scope.AWREADY),
                .scope_data_awvalid(scope.AWVALID),
                .scope_data_bready(scope.BREADY),
                .scope_data_bresp(scope.BRESP),
                .scope_data_bvalid(scope.BVALID),
                .scope_data_wdata(scope.WDATA),
                .scope_data_wready(scope.WREADY),
                .scope_data_wstrb(scope.WSTRB),
                .scope_data_wvalid(scope.WVALID),
                .dma_done(dma_done)
            );
        end else begin

        ps PS (
            .IO_clock(io_clock),
            .logic_clock(logic_clock),
            .reset(reset),
            .axi_out_araddr(axi_out.ARADDR),
            .axi_out_arprot(axi_out.ARPROT),
            .axi_out_arready(axi_out.ARREADY),
            .axi_out_arvalid(axi_out.ARVALID),
            .axi_out_awaddr(axi_out.AWADDR),
            .axi_out_awprot(axi_out.AWPROT),
            .axi_out_awready(axi_out.AWREADY),
            .axi_out_awvalid(axi_out.AWVALID),
            .axi_out_bready(axi_out.BREADY),
            .axi_out_bresp(axi_out.BRESP),
            .axi_out_bvalid(axi_out.BVALID),
            .axi_out_rdata(axi_out.RDATA),
            .axi_out_rready(axi_out.RREADY),
            .axi_out_rresp(axi_out.RRESP),
            .axi_out_rvalid(axi_out.RVALID),
            .axi_out_wdata(axi_out.WDATA),
            .axi_out_wready(axi_out.WREADY),
            .axi_out_wstrb(axi_out.WSTRB),
            .axi_out_wvalid(axi_out.WVALID),
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
            .scope_data_awaddr(scope.AWADDR),
            .scope_data_awburst(scope.AWBURST),
            .scope_data_awcache(scope.AWCACHE),
            .scope_data_awid(scope.AWID),
            .scope_data_awlen(scope.AWLEN),
            .scope_data_awlock(scope.AWLOCK),
            .scope_data_awqos(scope.AWQOS),
            .scope_data_awprot(scope.AWPROT),
            .scope_data_awready(scope.AWREADY),
            .scope_data_awvalid(scope.AWVALID),
            .scope_data_awregion(scope.AWREGION),
            .scope_data_awsize(scope.AWSIZE),
            .scope_data_bid(scope.BID),
            .scope_data_bready(scope.BREADY),
            .scope_data_bresp(scope.BRESP),
            .scope_data_bvalid(scope.BVALID),
            .scope_data_wdata(scope.WDATA),
            .scope_data_wready(scope.WREADY),
            .scope_data_wlast(scope.WLAST),
            .scope_data_wstrb(scope.WSTRB),
            .scope_data_wvalid(scope.WVALID),
            .dma_done(dma_done)
        );
        end


    endgenerate

endmodule