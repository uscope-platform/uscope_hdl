`timescale 1 ps / 1 ps

module Data_source_wrapper(
    input wire aclk_0,
    output wire [15:0]channel_1_tdata,
    output wire channel_1_tvalid,
    output wire [15:0]channel_2_tdata,
    output wire channel_2_tvalid,
    output [15:0]channel_3_tdata,
    output wire channel_3_tvalid,
    output wire [15:0]channel_4_tdata,
    output wire channel_4_tvalid,
    output wire [15:0]channel_5_tdata,
    output wire channel_5_tvalid,
    output wire [15:0]channel_6_tdata,
    output wire channel_6_tvalid
);

    Data_source Data_source_i(
        .aclk_0(aclk_0),
        .channel_1_tdata(channel_1_tdata),
        .channel_1_tvalid(channel_1_tvalid),
        .channel_2_tdata(channel_2_tdata),
        .channel_2_tvalid(channel_2_tvalid),
        .channel_3_tdata(channel_3_tdata),
        .channel_3_tvalid(channel_3_tvalid),
        .channel_4_tdata(channel_4_tdata),
        .channel_4_tvalid(channel_4_tvalid),
        .channel_5_tdata(channel_5_tdata),
        .channel_5_tvalid(channel_5_tvalid),
        .channel_6_tdata(channel_6_tdata),
        .channel_6_tvalid(channel_6_tvalid)
    );
endmodule
