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

module axi_dma_bursting_mc #(
    parameter int N_CHANNELS = 6,
    parameter int  ADDR_WIDTH = 32,
    parameter int DEST_WIDTH = 16,
    parameter int USER_WIDTH = 16,
    parameter int OUTPUT_AXI_WIDTH = 128,
    parameter int  MAX_TRANSFER_SIZE = 65536,
    parameter int  BURST_SIZE = 16,
    int CHANNEL_SAMPLES = 1024
)(
    input wire clock,
    input wire reset,
    input wire disable_dma,
    input wire buffer_full,
    input wire [63:0] dma_base_addr,
    input wire  [$clog2(MAX_TRANSFER_SIZE):0] packet_length,
    axi_stream.slave data_in[N_CHANNELS],
    AXI.master axi_out,
    output reg dma_done
);


    //////////////////////////////////////////////
    //        CHANNEL SELECTION LOGIC           //
    //////////////////////////////////////////////
    reg [7:0] selector = 0;

    axi_stream #(.DEST_WIDTH(DEST_WIDTH), .USER_WIDTH(USER_WIDTH), .DATA_WIDTH(32)) selected_in();


    channel_selector #(
        .N_CHANNELS(N_CHANNELS),
        .DATA_WIDTH(32),
        .DEST_WIDTH(DEST_WIDTH),
        .USER_WIDTH(USER_WIDTH)
    ) selection_logic (
        .clock(clock),
        .reset(reset),
        .selector(selector),
        .data_in(data_in),
        .data_out(selected_in)
    );
    //////////////////////////////////////////////
    //                 DMA LOGIC                //
    //////////////////////////////////////////////

    axi_stream #(.DEST_WIDTH(DEST_WIDTH), .USER_WIDTH(USER_WIDTH), .DATA_WIDTH(OUTPUT_AXI_WIDTH)) upsized_data();
    axi_stream #(.DEST_WIDTH(DEST_WIDTH), .USER_WIDTH(USER_WIDTH), .DATA_WIDTH(64)) upsizer_in();

    localparam ADDRESS_INCREMENT = 8;

    localparam BEAT_SIZE = OUTPUT_AXI_WIDTH/8;

    assign upsizer_in.data = {selected_in.user[USER_WIDTH-1:0], selected_in.dest[DEST_WIDTH-1:0], selected_in.data[31:0]};
    assign upsizer_in.dest = 0;
    assign upsizer_in.valid = selected_in.valid;
    assign upsizer_in.user = 0;
    assign upsizer_in.tlast = 0;
    assign selected_in.ready = upsizer_in.ready;

    upsizer#(
        .INPUT_WIDTH(64),
        .OUTPUT_WIDTH(OUTPUT_AXI_WIDTH),
        .DEST_WIDTH(DEST_WIDTH),
        .USER_WIDTH(USER_WIDTH)
    ) data_upsizer(
        .clock(clock),
        .reset(reset),
        .data_in(upsizer_in),
        .data_out(upsized_data)
    );

    enum reg [2:0] {
        writer_idle = 0,
        writer_start_burst = 1,
        writer_dma_send = 2,
        writer_wait_ready = 3,
        writer_wait_response = 4,
        writer_bump_selector = 5
    } writer_state;


    reg [63:0] target_base;


    reg [$clog2(MAX_TRANSFER_SIZE):0] burst_counter = 0;

    wire [ADDR_WIDTH-1:0] current_target_address;
    assign current_target_address = target_base + burst_counter*BEAT_SIZE*BURST_SIZE; 

    localparam reg [1:0] TRACKER_ADVANCE = OUTPUT_AXI_WIDTH/64;

    reg [15:0] transfers_tracker = 0;

    reg [3:0] beats_counter = 0;

    initial begin
        axi_out.AWVALID = 0;
        axi_out.WVALID  = 0;
        axi_out.ARVALID = 0;
        axi_out.RREADY <= 1;
    end

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
            axi_out.AWSIZE <= OUTPUT_AXI_WIDTH==128 ? 'b100 : 'b11;
            axi_out.WSTRB <= OUTPUT_AXI_WIDTH==128 ? 'hFFFF : 'hFF;

            axi_out.WVALID <= 0;

            axi_out.WUSER <= 0;
            axi_out.WLAST <= 0;

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

            upsized_data.ready <= 0;

            dma_done <= 0;
            writer_state <= writer_idle;
        end else begin
            if(axi_out.WVALID & axi_out.WREADY)begin
                 transfers_tracker  <= transfers_tracker +TRACKER_ADVANCE;
            end
            axi_out.BREADY <= 1;
            axi_out.AWVALID <= 0;
            dma_done <= 0;
            case (writer_state)
                writer_idle:begin
                    transfers_tracker <= 0;
                    beats_counter <= 0;
                    if(buffer_full & !disable_dma)begin
                        target_base <= dma_base_addr;
                        writer_state <= writer_start_burst;
                    end
                end
                writer_start_burst:begin
                    if(axi_out.AWREADY)begin
                        upsized_data.ready <= 1;
                        beats_counter <= 0;
                        writer_state <= writer_dma_send;
                        axi_out.AWADDR <= current_target_address;
                        axi_out.AWVALID <= 1;
                        axi_out.AWBURST <= 1;
                        axi_out.WLAST <= 0;
                        axi_out.AWLEN <= BURST_SIZE-1;
                    end

                end
                writer_dma_send:begin
                    if(upsized_data.valid) begin
                        if(beats_counter== BURST_SIZE-1)begin
                            axi_out.WLAST <= 1;
                            writer_state <= writer_wait_response;
                            upsized_data.ready <= 0;
                        end else begin
                            writer_state <= writer_wait_ready;
                            upsized_data.ready <= 0;
                            beats_counter <= beats_counter + 1;
                        end
                        axi_out.WDATA <= upsized_data.data;
                        axi_out.WVALID <= 1;
                    end
                end
                writer_wait_ready:begin
                     if(axi_out.WREADY)begin
                        axi_out.WVALID <= 0;
                        writer_state <= writer_dma_send;
                        upsized_data.ready <= 1;
                     end
                end
                writer_wait_response:begin
                    if(axi_out.WREADY) axi_out.WVALID <= 0;

                    if(axi_out.BVALID)begin
                        axi_out.BREADY <= 0;
                        if(transfers_tracker == CHANNEL_SAMPLES)begin
                            writer_state <= writer_bump_selector;
                            transfers_tracker <= 0;
                        end else begin
                            burst_counter <= burst_counter +1;
                            writer_state <= writer_start_burst;
                        end
                    end
                end
                writer_bump_selector:begin
                    if((selector==N_CHANNELS-1) || disable_dma)begin
                        selector <= 0;
                        writer_state <= writer_idle;
                        burst_counter <= 0;
                        dma_done <= 1;
                    end else begin
                        selector <= selector + 1;
                        burst_counter <= burst_counter +1;
                        writer_state <= writer_start_burst;
                    end
                end
            endcase
        end
    end

endmodule
