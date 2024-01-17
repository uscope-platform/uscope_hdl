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


`timescale 1 ns / 100 ps
`include "interfaces.svh"

module axi_dma #(
    parameter ADDR_WIDTH = 32,
    parameter DEST_WIDTH = 8,
    parameter MAX_TRANSFER_SIZE = 65536
)(
    input wire clock,
    input wire reset,
    input wire enable,
    input wire [63:0] dma_base_addr,
    axi_stream.slave data_in,
    AXI.master axi_out,
    output reg dma_done
);

    axi_stream #(.DEST_WIDTH(DEST_WIDTH)) buffered_data();

    localparam FIFO_DEPTH = 8192;

    axis_fifo_xpm #(
        .SIM_ASSERT_CHK(0),
        .DEST_WIDTH(DEST_WIDTH),
        .DATA_WIDTH(32),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dma_fifo(
        .clock(clock),
        .reset(reset),
        .in(data_in),
        .out(buffered_data)
    );

    enum reg [2:0] {
        writer_idle = 0,
        writer_read_LSB = 1,
        writer_dma_send = 2,
        writer_send_data = 3,
        writer_wait_response = 4
    } writer_state;
    

    reg [$clog2(MAX_TRANSFER_SIZE)-1:0] fifo_level = 0;
    always_ff @(posedge clock) begin
        if(data_in.valid & !buffered_data.ready) begin
            fifo_level <= fifo_level + 1;
        end
        if(!data_in.valid & buffered_data.ready) begin
            fifo_level <= fifo_level - 1;
        end
    end


    reg [63:0] target_base;

    reg [$clog2(MAX_TRANSFER_SIZE)-1:0] packet_length = 0;


    reg [$clog2(MAX_TRANSFER_SIZE)-1:0] progress_counter = 0;
    wire dma_end_condition;
    assign dma_end_condition = progress_counter == packet_length-2;
   

    wire [ADDR_WIDTH-1:0] current_target_address;
    assign current_target_address = target_base + progress_counter*8;


    reg [63:0] axi_low_word = 0;
    reg [63:0] axi_high_word = 0;

    assign axi_out.WDATA  = {axi_high_word, axi_low_word};

    always_ff @(posedge clock) begin
        if(~reset)begin

            axi_out.AWLEN <= 0;
            axi_out.AWID <= 2;
            axi_out.AWVALID <= 0;
            axi_out.AWPROT <= 0;
            axi_out.AWADDR <= 0;
            axi_out.AWUSER <= 0;
            axi_out.AWQOS <= 0;
            axi_out.AWREGION <= 0;
            axi_out.AWCACHE <= 0;
            axi_out.AWBURST <= 0;
            axi_out.AWLOCK <= 0;
            axi_out.AWSIZE <= 'b100;


            axi_out.WVALID <= 0;
            
            axi_out.WSTRB <= 'hFFFF;
            axi_out.WUSER <= 0;
            axi_out.WLAST <= 1;

            axi_out.ARID <= 2;
            axi_out.ARLEN <= 0;
            axi_out.ARSIZE <= 0;
            axi_out.ARBURST <= 0;
            axi_out.ARLOCK <= 0;
            axi_out.ARCACHE <= 0;
            axi_out.ARQOS <= 0;
            axi_out.ARREGION <= 0;
            axi_out.ARUSER <= 0;
            axi_out.ARVALID <= 0;
            axi_out.ARADDR <= 0;
            axi_out.ARPROT <= 0;
            axi_out.RREADY <= 1;
            axi_out.BREADY <= 1;

            buffered_data.ready <= 0;
            dma_done <= 0;
            writer_state <= writer_idle;
        end else begin
            axi_out.BREADY <= 1;
            axi_out.AWVALID <= 0;
            axi_out.WVALID <= 0;
            dma_done <= 0;
            case (writer_state)
                writer_idle:begin
                    if(data_in.tlast)begin
                        target_base <= dma_base_addr;
                        packet_length <= (fifo_level+1);
                        buffered_data.ready <= 1;
                        progress_counter <= 0;
                        writer_state <= writer_read_LSB;
                    end
                end
                writer_read_LSB:begin
                    writer_state <= writer_dma_send;
                    axi_low_word[31:0] <= buffered_data.data;
                    axi_low_word[63:32] <= buffered_data.dest;
                end
                writer_dma_send:begin
                    buffered_data.ready <= 0;
                    if(axi_out.WREADY & axi_out.AWREADY) begin
                        axi_out.AWADDR <= current_target_address;
                        axi_out.AWVALID <= 1;
                        axi_high_word[31:0] <= buffered_data.data;
                        axi_high_word[63:32] <= {{(32-DEST_WIDTH){1'b0}}, buffered_data.dest[DEST_WIDTH-1:0]};
                        axi_out.WVALID <= 1;
                        writer_state <= writer_wait_response;
                    end
                end
                writer_wait_response:begin
                    if(axi_out.BVALID)begin
                        axi_out.BREADY <= 0;
                        if(dma_end_condition)begin
                            writer_state <= writer_idle;
                            dma_done <= 1;
                        end else begin
                            writer_state <= writer_read_LSB;
                            buffered_data.ready <= 1;
                            progress_counter <= progress_counter + 2;
                        end                       
                    end
                end
            endcase
        end
    end

endmodule