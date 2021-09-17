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


module ad2s1210_tl (
    input wire R_SDO_RES,
    output wire R_SDI_RES,
    output wire R_WR,
    output wire R_SCK_RES,
    output wire R_A0,
    output wire R_A1,
    output wire R_RE0,
    output wire R_RE1,
    output wire R_SAMPLE,
    output wire R_RESET
);

    wire SS;

    assign R_WR = SS;
    wire clock, reset, start_read, dma_done;
    wire read_angle, read_speed;
    Simplebus s();
    Simplebus slave_1();
    Simplebus slave_2();
    Simplebus slave_3();
    
    defparam ch_1.DATA_WIDTH = 16;
    axi_stream ch_1();
    defparam ch_2.DATA_WIDTH = 16;
    axi_stream ch_2();
    axi_stream ch_3();
    axi_stream ch_4();
    axi_stream ch_5();
    axi_stream ch_6();
    axi_stream ch_7();
    axi_stream ch_8();

    APB apb();
    AXI fcore_dummy();
    axi_lite dma_mgr();
    axi_stream out();
    axi_stream resolver_out();

    Zynq_axis_wrapper PS(
        .APB(apb),
        .Logic_Clock(clock),
        .Reset(reset),
        .dma_axi(dma_mgr),
        .fcore_axi(fcore_dummy),
        .scope(out),
        .dma_done(dma_done)
    );

    
    APB_to_Simplebus bridge(
        .PCLK(clock),
        .PRESETn(reset),
        .apb(apb),
        .spb(s)
    );

    parameter BASE_ADDRESS = 'h43c00000;

    defparam xbar.SLAVE_1_LOW = BASE_ADDRESS;
    defparam xbar.SLAVE_1_HIGH = BASE_ADDRESS+'h100;
    defparam xbar.SLAVE_2_LOW = BASE_ADDRESS+'h100;
    defparam xbar.SLAVE_2_HIGH = BASE_ADDRESS+'h200;
    defparam xbar.SLAVE_3_LOW = BASE_ADDRESS+'h300;
    defparam xbar.SLAVE_3_HIGH = BASE_ADDRESS+'h400;
    
    SimplebusInterconnect_M1_S3 xbar(
        .clock(clock),
        .master(s),
        .slave_1(slave_1),
        .slave_2(slave_2),
        .slave_3(slave_3)
    );

    wire [23:0] res_data;
    wire [7:0] res_fault;
    wire res_valid, res_type;


    always_ff@(posedge clock)begin
        if(~reset)begin
            ch_1.valid <= 0;
            ch_1.data <= 0;
            ch_2.valid <= 0;
            ch_2.data <= 0;
        end else begin
            if(res_valid)begin
                case (res_type)
                    0:begin
                        ch_1.data <= res_data;
                        ch_1.dest <= 1;
                        ch_1.valid <= 1;
                    end 
                    1: begin
                        ch_2.data <= res_data;
                        ch_2.dest <= 2;
                        ch_2.valid <= 1;
                    end 
                endcase
            end else begin
                ch_1.valid <= 0;
                ch_2.valid <= 0;
            end
        end
    end

    defparam scope.BASE_ADDRESS = BASE_ADDRESS+'h300;
    uScope scope (
        .clock(clock),
        .reset(reset),
        .dma_done(dma_done),
        .in_1(ch_1),
        .in_2(ch_2),
        .in_3(ch_3),
        .in_4(ch_4),
        .in_5(ch_5),
        .in_6(ch_6),
        .in_7(ch_7),
        .in_8(ch_8),
        .dma_axi(dma_mgr),
        .out(out),
        .sb(slave_3)
    );

    assign res_data = resolver_out.data;
    assign res_type = resolver_out.dest;
    assign res_fault = resolver_out.user;
    assign res_valid = resolver_out.valid;
    
    defparam test.BASE_ADDRESS = BASE_ADDRESS;
    ad2s1210 test(
        .clock(clock),
        .reset(reset),
        .read_angle(read_angle),
        .read_speed(read_speed),
        .MOSI(R_SDI_RES),
        .MISO(R_SDO_RES),
        .SS(SS),
        .SCLK(R_SCK_RES),
        .R_A({R_A1, R_A0}),
        .R_RES({R_RE1, R_RE0}),
        .R_SAMPLE(R_SAMPLE),
        .R_RESET(R_RESET),
        .data_out(resolver_out),
        .sb(slave_1)
    );


    defparam tb_gen.BASE_ADDRESS = BASE_ADDRESS+'h100;
    enable_generator_2 tb_gen(
        .clock(clock),
        .reset(reset),
        .gen_enable_in(0),
        .enable_out_1(read_angle),
        .enable_out_2(read_speed),
        .sb(slave_2)
    );

endmodule