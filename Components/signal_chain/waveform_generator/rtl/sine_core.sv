`timescale 10ns / 1ns
`include "interfaces.svh"

module sine_core #(
    integer N_PARAMETERS = 16
)(
    input wire clock,
    input wire reset,
    input wire trigger,
    input wire [31:0] parameters[N_PARAMETERS-1:0],
    axi_stream.master data_out
);


    wire [31:0] dc_offset;
    assign dc_offset = parameters[0];

    wire [31:0] amplitude;
    assign amplitude = parameters[1];

    wire [31:0] frequency;
    assign frequency = parameters[2];

    wire [31:0] phase;
    assign phase = parameters[3];

    initial begin
        data_out.data = 0;
        data_out.dest = 0;
        data_out.tlast = 0;
        data_out.valid = 0;
        data_out.user = 0;
    end

endmodule
