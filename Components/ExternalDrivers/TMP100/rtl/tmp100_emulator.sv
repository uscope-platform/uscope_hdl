
module tmp100_emulator #(
    parameter reg [7:0] ADDRESS = 0,
    parameter integer AVERAGE_TEMPERATURE = 55,
    parameter integer TEMPERATURE_DELTA = 10
)(
    input wire clock,
    input wire reset,
    inout wire SDA,
    inout wire SCL
);

    reg [11:0] temperature;
    reg prev_sda, prev_scl;

    always_ff @(posedge clock) begin
        prev_sda <= SDA;
        prev_scl <= SCL;

        if(~SDA && prev_sda && SCL) begin
            temperature <= AVERAGE_TEMPERATURE*16 + $urandom_range(0, TEMPERATURE_DELTA*2*16)-(TEMPERATURE_DELTA*16);
        end
    end

    axi_stream slave_rx();
    i2c_slave_tristate  #(
        .SLAVE_ADDRESS(ADDRESS)
    ) tmp_emulator(
        .clock(clock),
        .SCL(SCL),
        .SDA(SDA),
        .data_in('{{temperature[3:0], 4'b0}, temperature[11:4]}),
        .data_out(slave_rx)
    );

endmodule
