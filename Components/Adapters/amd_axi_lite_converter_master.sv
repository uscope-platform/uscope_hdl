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
`timescale 10 ns / 1 ns
`include "vivado_interfaces.svh"

module amd_axi_lite_converter_master (
    vivado_axi4_lite_v1_0.slave axi_in,
    axi_lite.master axi_out
);

    
    assign axi_out.AWADDR  = axi_in.AWADDR;
    assign axi_out.AWPROT  = axi_in.AWPROT;
    assign axi_out.AWVALID = axi_in.AWVALID;
    assign axi_out.WDATA   = axi_in.WDATA;
    assign axi_out.WSTRB   = axi_in.WSTRB;
    assign axi_out.WVALID  = axi_in.WVALID;
    assign axi_out.BREADY  = axi_in.BREADY;
    assign axi_out.ARADDR  = axi_in.ARADDR;
    assign axi_out.ARPROT  = axi_in.ARPROT;
    assign axi_out.ARVALID = axi_in.ARVALID;
    assign axi_out.RREADY  = axi_in.RREADY;
    assign axi_in.AWREADY  = axi_out.AWREADY;
    assign axi_in.WREADY   = axi_out.WREADY;
    assign axi_in.BRESP    = axi_out.BRESP;
    assign axi_in.BVALID   = axi_out.BVALID;
    assign axi_in.ARREADY  = axi_out.ARREADY;
    assign axi_in.RDATA    = axi_out.RDATA;
    assign axi_in.RRESP    = axi_out.RRESP;
    assign axi_in.RVALID   = axi_out.RVALID;

endmodule
