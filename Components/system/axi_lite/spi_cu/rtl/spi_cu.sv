// Copyright 2026 Filippo Savi
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

module spi_cu #(
    parameter HIGH_RANGE_START = 15
) (
    input wire clock,
    input wire reset,
    input wire SCLK,
    input wire SS,
    input wire DATA,
    axi_lite.master axi_out
);

    axi_stream dummy_in();
    axi_lite dummy_axi();
    axi_stream #(.DATA_WIDTH(16)) rx_data();

    SPI_slave#(
        .N_CHANNELS(1),
        .REGISTERS_WIDTH(16),
        .OUTPUT_WIDTH(32)
    )receiver(
        .clock(clock),
        .reset(reset),
        .enable(1),
        .SCLK(SCLK),
        .MOSI(DATA),
        .SS(SS),
        .axi_in(dummy_axi),
        .spi_data_in('{dummy_in}),
        .spi_data_out('{rx_data})
    );

    axi_stream dummy_a();
    axi_stream dummy_b();
    axi_stream bus_write();

    axis_to_axil axil_if(
        .clock(clock),
        .reset(reset),
        .axis_write(bus_write),
        .axis_read_request(dummy_a),
        .axis_read_response(dummy_b),
        .axi_out(axi_out)
    );

    enum logic [2:0]{
       idle = 0,
       address_h = 1,
       data_l = 2,
       data_h = 3,
       write = 4
    } cu_state = idle;

    reg[31:0] address;
    reg[31:0] data;

    always_ff @(posedge clock)begin
        if(!reset)begin
            cu_state <= idle;
            rx_data.ready <= 1;
        end else begin
            bus_write.valid <= 0;
            case (cu_state)
                idle: begin
                    if(rx_data.valid)begin
                        address <= {16'h0, rx_data.data};
                        cu_state <= data_l;
                    end
                end
                data_l: begin
                     if(rx_data.valid)begin
                        data <= {16'h0, rx_data.data};
                        if(address[HIGH_RANGE_START])begin
                            cu_state <= address_h;
                        end else begin
                            cu_state <= write;
                        end
                    end
                end
                address_h: begin
                    if(rx_data.valid)begin
                        address[31:16]<= rx_data.data;
                        cu_state <= data_h;
                    end
                end
                data_h: begin
                    if(rx_data.valid)begin
                        data[31:16]<= rx_data.data;
                        cu_state <= write;
                    end
                end
                write: begin
                    if(bus_write.ready)begin
                        bus_write.data <= data;
                        bus_write.dest <= address;
                        bus_write.valid <= 1;
                    end
                    cu_state <= idle;
                end
            endcase
        end
    end

endmodule
