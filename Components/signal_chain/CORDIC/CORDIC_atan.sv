module CORDIC_atan#(
    parameter integer RESOLUTION = 16
)(
    input wire clock,
    input wire reset,
    axi_stream.slave x, 
    axi_stream.slave y,
    axi_stream.master out
);


    axi_stream initial_condition();


    CORDIC_quadrant_selector#(
        .RESOLUTION(RESOLUTION)
    )pre_rotator(
        .clock(clock),
        .reset(reset),
        .x_in(x),
        .y_in(y),
        .prescaled_out(initial_condition)
    );

    CORDIC_core#(
        .RESOLUTION(RESOLUTION)
    )serial_core(
        .clock(clock),
        .reset(reset),
        .prescaled_out(initial_condition),
        .out(out)
    );



endmodule