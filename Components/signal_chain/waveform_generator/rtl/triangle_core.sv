`timescale 10ns / 1ns
`include "interfaces.svh"

module triangle_core #(
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

    wire [31:0] period;
    assign period = parameters[2];

    wire [31:0] phase;
    assign phase = parameters[3];

    wire [31:0] duty;
    assign duty = parameters[4];

    wire [31:0] ramp_increment;
    assign ramp_increment = parameters[5];

    wire [31:0] dest_out;
    assign dest_out = parameters[6];

    wire [31:0] user_out;
    assign user_out = parameters[7];


    reg[23:0] generator_counter = 0;
    reg running = 0;

    initial begin
        data_out.data = 0;
        data_out.dest = 0;
        data_out.tlast = 0;
        data_out.valid = 0;
        data_out.user = 0;
    end


    wire down_ramp;
    assign down_ramp = generator_counter > duty-1;

    always_ff@(posedge clock)begin
        data_out.tlast <= 0;
        data_out.valid <= 0;
        if(!running)begin
            if(trigger)begin
                running <= 1;
            end
            generator_counter <= phase;
        end else begin
            if(trigger)begin
                if(generator_counter==period-1)begin
                    generator_counter <= 0;
                end else begin
                    if(down_ramp) begin
                        generator_counter <= generator_counter-ramp_increment;
                    end else begin
                        generator_counter <= generator_counter+ramp_increment;
                    end
                end
                data_out.data <= generator_counter;
                data_out.dest <= dest_out;
                data_out.user <= user_out;
                data_out.valid <= 1;
                data_out.tlast <= 1;

            end
        end
    end


    always_comb begin

    end

endmodule
