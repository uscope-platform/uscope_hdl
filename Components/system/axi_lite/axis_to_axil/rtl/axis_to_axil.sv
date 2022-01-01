// Copyright 2021 Filippo Savi
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


`timescale 1 ns / 100 ps
`include "interfaces.svh"

module axis_to_axil (
    input wire clock,
    input wire reset, 
    axi_stream.slave axis_write,
    axi_stream.slave axis_read_request,
    axi_stream.master axis_read_response,
    axi_lite.master axi_out
);


    reg[31:0] latched_address;
    reg[31:0] latched_data;

    enum reg [2:0] {
        idle = 0,
        send_address = 1,
        send_data = 2,
        wait_response = 3
    } writer_state;

    assign axis_write.ready = writer_state == idle;

    always_ff @(posedge clock) begin
        if(!reset)begin
            axis_write.ready <= 1;
            axi_out.WDATA <= 0;
            axi_out.WVALID <= 0;
            axi_out.AWADDR <= 0;
            axi_out.AWVALID <= 0;
            axi_out.BREADY <= 1;
            axi_out.WSTRB <= 'hFF;

            writer_state <= idle;
        end else begin
            axi_out.BREADY <= 1;
            axi_out.AWVALID <= 0;
            axi_out.WVALID <= 0;
            case (writer_state)
                idle:begin
                    if(axis_write.valid)begin
                        if(axi_out.WREADY & axi_out.AWREADY) begin
                            axi_out.AWADDR <= axis_write.dest;
                            axi_out.AWVALID <= 1;
                            axi_out.WDATA <= axis_write.data;
                            axi_out.WVALID <= 1;
                            writer_state <= wait_response;
                        end else if(axi_out.AWREADY) begin
                            axi_out.AWADDR <= axis_write.dest;
                            latched_data <= axis_write.data;
                            axi_out.AWVALID <= 1;
                            writer_state <= send_data;
                        end else begin
                            latched_data <= axis_write.data;
                            latched_address <= axis_write.dest;
                            writer_state <= send_address;
                        end
                    end
                end
                send_address:begin
                    if(axi_out.AWREADY) begin
                        axi_out.AWADDR <= latched_address;
                        axi_out.AWVALID <= 1;
                        writer_state <= send_data;
                    end
                end
                send_data:begin
                    if(axi_out.WREADY) begin
                        axi_out.WDATA <= latched_data;
                        axi_out.WVALID <= 1;
                        writer_state <= wait_response;
                    end
                end
                wait_response:begin
                    if(axi_out.BVALID)begin
                        axi_out.BREADY <= 0;
                        writer_state <= idle;
                    end
                end
            endcase
        end
    end




    always_ff @(posedge clock) begin
        if(!reset)begin
            axi_out.RDATA <= 0;
            axi_out.RVALID <= 0;
            axi_out.ARADDR <= 0;
            axi_out.ARVALID <= 0;
            axi_out.RREADY <= 1;
        
        end else begin
        
        end
    end




endmodule
