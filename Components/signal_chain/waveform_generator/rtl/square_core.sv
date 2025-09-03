`timescale 10ns / 1ns
`include "interfaces.svh"

module square_core #(
    parameter int N_PARAMETERS = 16
)(
    input wire clock,
    input wire reset,
    input wire trigger,
    input wire [31:0] parameters[N_PARAMETERS-1:0],
    axi_stream.master data_out
);


    wire [31:0] v_on;
    assign v_on = parameters[0];

    wire [31:0] v_off;
    assign v_off = parameters[1];

    wire [31:0] t_delay;
    assign t_delay = parameters[2];

    wire [31:0] t_on;
    assign t_on = parameters[3];

    wire [31:0] period;
    assign period = parameters[4];

    wire [31:0] dest_out;
    assign dest_out = parameters[5];

    wire [31:0] user_out;
    assign user_out = parameters[6];


    reg[23:0] generator_counter = 0;
    reg running = 0;

    initial begin
        data_out.data = 0;
        data_out.dest = 0;
        data_out.tlast = 0;
        data_out.valid = 0;
        data_out.user = 0;
    end

    wire output_status;
    assign output_status = generator_counter > t_on;

    always_ff@(posedge clock)begin

        data_out.tlast <= 0;
        data_out.valid <= 0;
        if(!running)begin
            if(trigger)begin
                running <= 1;
                data_out.data <= output_status ? v_on : v_off;
                data_out.dest <= dest_out;
                data_out.user <= user_out;
                data_out.tlast <= 1;
                data_out.valid <= 1;
            end
            generator_counter <= t_delay;
        end else begin
            if(generator_counter==period-1)begin
                generator_counter <= 0;
            end else begin
                generator_counter <= generator_counter+1;
            end

            if(trigger)begin
                data_out.data <= output_status ? v_on : v_off;
                data_out.dest <= dest_out;
                data_out.user <= user_out;
                data_out.tlast <= 1;
                data_out.valid <= 1;
            end
        end
    end


endmodule
