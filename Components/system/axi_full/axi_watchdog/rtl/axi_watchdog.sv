// Copyright 2024 Filippo Savi
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

module axi_watchdog #(
    integer TIMEOUT = 8192
) (
    input wire        clock,
    input wire        reset,
    AXI.slave  axi_in,
    AXI.master axi_out
);


    reg reset_read = 0;
    reg reset_write = 0;

    assign in.AWREADY = out.AWREADY | reset_write;
    assign in.BVALID = out.BVALID | reset_write;
    assign in.WREADY = out.WREADY | reset_write;
    
    assign in.ARREADY = out.ARREADY | reset_read;
    assign in.RVALID = out.RVALID | reset_read;

    assign in.BID = out.BID;
    assign in.BRESP = out.BRESP;
    assign in.BUSER = out.BUSER;

    assign in.RDATA = out.RDATA;
    assign in.RRESP = out.RRESP;
    assign in.RLAST = out.RLAST;
    assign in.RUSER = out.RUSER;

    

    always @( posedge clock ) begin
        out.AWID <= in.AWID;
        out.AWADDR <= in.AWADDR;
        out.AWLEN <= in.AWLEN;
        out.AWSIZE <= in.AWSIZE;
        out.AWBURST <= in.AWBURST;
        out.AWLOCK <= in.AWLOCK;
        out.AWCACHE <= in.AWCACHE;
        out.AWPROT <= in.AWPROT;
        out.AWQOS <= in.AWQOS;
        out.AWREGION <= in.AWREGION;
        out.AWUSER <= in.AWUSER;
        out.AWVALID <= in.AWVALID;
        
        out.WDATA <= in.WDATA;
        out.WLAST <= in.WLAST;
        out.WUSER <= in.WUSER;
        out.WVALID <= in.WVALID;
        out.WSTRB <= in.WSTRB;
        out.BREADY <= in.BREADY;

        out.ARID <= in.ARID;
        out.ARADDR <= in.ARADDR;
        out.ARLEN <= in.ARLEN;
        out.ARSIZE <= in.ARSIZE;
        out.ARBURST <= in.ARBURST;
        out.ARLOCK <= in.ARLOCK;
        out.ARCACHE <= in.ARCACHE;
        out.ARPROT <= in.ARPROT;
        out.ARQOS <= in.ARQOS;
        out.ARREGION <= in.ARREGION;
        out.ARUSER <= in.ARUSER;
        out.ARVALID <= in.ARVALID;
        out.RREADY <= in.RREADY;
    end

    reg [$clog2(TIMEOUT)-1:0] watchdog = 0;

    enum reg [2:0] {
        idle = 0,
        in_read = 1,
        in_write = 2,
        do_reset_read = 3,
        do_reset_write = 4
    } watchdog_state = idle;

    always_ff @(posedge clock) begin

        reset_write <= 0;
        reset_read <= 0;
        case (watchdog_state)
            idle:begin
                if(in.AWVALID) begin
                    watchdog_state<= in_write;
                    watchdog <= 0;
                end
                if(in.ARVALID) begin
                    watchdog_state<= in_read;
                    watchdog <= 0;
                end
            end
            in_read: begin
                if(watchdog == TIMEOUT-1)begin
                    watchdog_state <= do_reset_read;
                    reset_read <= 1;
                end else begin
                    watchdog <= watchdog+1;
                end
            end
            in_write: begin
                if(watchdog == TIMEOUT-1)begin
                    watchdog_state <= do_reset_write;
                    reset_write <= 1;
                end else begin
                    watchdog <= watchdog+1;
                end
            end 
            do_reset_read: begin
                state <= idle;
            end
            do_reset_write: begin
                state <= idle;
            end 
        endcase
    end
endmodule
