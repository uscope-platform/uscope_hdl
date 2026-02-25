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

module spi_simplified_master_tb();

    logic clock, reset;

    localparam N_CHANNELS=4;
    localparam randomized_test = 1;
    localparam packet_start = 37;
    localparam max_packet_size = 16;

    wire [N_CHANNELS-1:0] mosi;
    wire sclk;
    wire ss;
    reg [N_CHANNELS-1:0] miso;

    initial clock = 1;
    always #0.5 clock = ~clock;
    event reset_done, config_done;

    axi_lite ctrl_axi();
    axi_stream spi_in();
    axi_stream spi_out();

    spi_simplified_master#(
        .N_CHANNELS(4),
        .REGISTERS_WIDTH(16),
        .OUTPUT_WIDTH(32),
        .DEFAULT_LENGTH(16),
        .STARTING_DEST(packet_start),
        .MAX_PACKET_SIZE(127)
    )UUT(
        .clock(clock),
        .reset(reset),
        .miso(miso),
        .sclk(sclk),
        .mosi(mosi),
        .ss(ss),
        .axi_in(ctrl_axi),
        .spi_data_in(spi_in),
        .spi_data_out(spi_out)
    );


    initial begin
        ctrl_axi.initialize_master();
        reset <=1;
        #3 reset<=0;
        #5 reset <=1;
        ->reset_done;
        #10;
        ->config_done;
    end

    event transmission_start, transmission_done;

    reg [15:0] sent_data [max_packet_size-1:0];

    reg [15:0] ss_delay = 3;
    reg [15:0] transfer_length = 16;
    reg [7:0] spi_divider = 2;
    reg ss_polarity = 0;
    reg sclk_polarity = 0;
    reg latching_edge = 0;
    reg lsb_first = 0;
    reg [$clog2(max_packet_size)-1:0] packet_length = 8;

    wire [31:0] control_register;
    assign control_register = {lsb_first,latching_edge,sclk_polarity,ss_polarity,spi_divider};

    initial begin
        sent_data = '{default:0};
        spi_in.initialize();
        spi_out.ready = 1;
        miso = 0;
        @(config_done);
        forever begin
            if(randomized_test)begin
                ss_delay = $urandom() % 8;
                spi_divider = $urandom() % 8;
                ss_polarity = $urandom_range(0,1);
                sclk_polarity = $urandom_range(0,1);
                latching_edge = $urandom_range(0,1);
                lsb_first = $urandom_range(0,1);
                transfer_length = 8 + ($urandom() % 9);
                packet_length = 4*$urandom_range(1,3);
            end

            #10 ctrl_axi.write(0, control_register);
            #10 ctrl_axi.write(4, {ss_delay, ss_delay});
            #10 ctrl_axi.write(8, transfer_length);
            for(int i = 0; i<packet_length; i++) begin
                sent_data[i] =  $urandom_range(0, (1<<transfer_length)-1);
                spi_in.write_tlast(i+packet_start, sent_data[i], i == packet_length-1);
                if(i == packet_length-1) ->transmission_start;
                end
            @(transmission_done);
            #30;
        end

    end


    reg [15:0] received_data [max_packet_size-1:0];
    reg [15:0] transfers_counter = 0;
    always begin
        @(transmission_start);
        received_data = '{default:0};
        transfers_counter = 0;
        while (transfers_counter < packet_length) begin
            if(ss_polarity)
                @(negedge ss);
            else
                @(posedge ss);
            for(int i  = 0; i< transfer_length; i++)begin
                if(sclk_polarity && ~latching_edge)
                    @(posedge sclk);
                else if(~sclk_polarity && ~latching_edge)
                    @(negedge sclk);
                if(sclk_polarity && latching_edge)
                    @(negedge sclk);
                else if(~sclk_polarity && latching_edge)
                    @(posedge sclk);

                for(int j = 0; j < N_CHANNELS; j++)begin
                    if(~lsb_first)
                        received_data[j+transfers_counter][transfer_length-1-i] = mosi[j];
                    else
                        received_data[j+transfers_counter][i] = mosi[j];
                end
            end
            transfers_counter = transfers_counter+ N_CHANNELS;
        end

        assert (received_data == sent_data)
        else begin
            for(int k = 0; k < packet_length; k++) begin
                if (received_data[k] !== sent_data[k]) begin
                    $display("  Channel [%0d]: Sent 0x%h, Received 0x%h",
                             k, sent_data[k], received_data[k]);
                    $stop();
                end
            end
        end
        if(ss_polarity)
            @(posedge ss);
        else
            @(negedge ss);
        ->transmission_done;
    end



endmodule
