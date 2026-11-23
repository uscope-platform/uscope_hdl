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
    integer TIMEOUT = 8192,
    integer CLEAR_CYCLES = 16
) (
    input wire        clock,
    input wire        reset,
    AXI.slave  in,
    AXI.master out
);


    reg reset_read = 0;
    reg reset_write = 0;

    assign in.AWREADY = out.AWREADY | reset_write;
    assign in.BVALID = out.BVALID | reset_write;
    assign in.BRESP = out.BRESP | {reset_write, 1'b0};
    assign in.WREADY = out.WREADY | reset_write;
    
    assign in.ARREADY = out.ARREADY | reset_read;
    assign in.RVALID = out.RVALID | reset_read;
    assign in.RRESP = out.RRESP | {reset_read, 1'b0};

    assign in.BID = out.BID;
    assign in.BUSER = out.BUSER;

    assign in.RDATA = out.RDATA;
    assign in.RLAST = out.RLAST  | reset_read;
    assign in.RUSER = out.RUSER;

    
    assign out.AWID = in.AWID;
    assign out.AWADDR = in.AWADDR;
    assign out.AWLEN = in.AWLEN;
    assign out.AWSIZE = in.AWSIZE;
    assign out.AWBURST = in.AWBURST;
    assign out.AWLOCK = in.AWLOCK;
    assign out.AWCACHE = in.AWCACHE;
    assign out.AWPROT = in.AWPROT;
    assign out.AWQOS = in.AWQOS;
    assign out.AWREGION = in.AWREGION;
    assign out.AWUSER = in.AWUSER;
    assign out.AWVALID = in.AWVALID;

    assign out.WDATA = in.WDATA;
    assign out.WLAST = in.WLAST;
    assign out.WUSER = in.WUSER;
    assign out.WVALID = in.WVALID;
    assign out.WSTRB = in.WSTRB;
    assign out.BREADY = in.BREADY;

    assign out.ARID = in.ARID;
    assign out.ARADDR = in.ARADDR;
    assign out.ARLEN = in.ARLEN;
    assign out.ARSIZE = in.ARSIZE;
    assign out.ARBURST = in.ARBURST;
    assign out.ARLOCK = in.ARLOCK;
    assign out.ARCACHE = in.ARCACHE;
    assign out.ARPROT = in.ARPROT;
    assign out.ARQOS = in.ARQOS;
    assign out.ARREGION = in.ARREGION;
    assign out.ARUSER = in.ARUSER;
    assign out.ARVALID = in.ARVALID;
    assign out.RREADY = in.RREADY;

    reg [$clog2(TIMEOUT)-1:0] watchdog = 0;
    reg [$clog2(CLEAR_CYCLES)-1:0] reset_timer = 0; 
    enum reg [2:0] {
        idle = 0,
        in_read = 1,
        in_write = 2,
        do_reset_read = 3,
        do_reset_write = 4
    } watchdog_state = idle;

    always_ff @(posedge clock) begin
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
                    reset_timer <= 0;
                    reset_read <= 1;
                end else begin
                    if(out.RVALID) begin
                        watchdog_state <= idle; 
                    end
                    watchdog <= watchdog+1;
                end
            end
            in_write: begin
                if(watchdog == TIMEOUT-1)begin
                    watchdog_state <= do_reset_write;
                    reset_timer <= 0;
                    reset_write <= 1;
                end else begin
                    if(out.BVALID) begin
                        watchdog_state <= idle; 
                    end
                    watchdog <= watchdog+1;
                end
            end 
            do_reset_read: begin
                if(reset_timer ==CLEAR_CYCLES-1)begin
                    watchdog_state <= idle;
                    reset_read <= 0;
                end else begin
                    reset_timer <= reset_timer +1;
                end
            end
            do_reset_write: begin
                if(reset_timer ==CLEAR_CYCLES-1)begin
                    watchdog_state <= idle;
                    reset_write <= 0;
                end else begin
                    reset_timer <= reset_timer +1;
                end
            end 
        endcase
    end
endmodule
