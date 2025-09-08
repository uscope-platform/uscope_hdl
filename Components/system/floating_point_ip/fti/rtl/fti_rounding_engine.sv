module fti_rounding_engine #(
    parameter DATA_WIDTH = 32
) (
    input  wire [23:0] data_in,
    input  wire mantissa_lsb,
    input  wire signed [7:0] lsb_index,
    output wire round_up
);


    function automatic logic get_bit (
        input logic [DATA_WIDTH:0] data_in,
        input logic [$clog2(DATA_WIDTH)-1:0] index
    );
        return (data_in >> index) & 1'b1;
    endfunction

    function automatic logic get_sticky (
        input logic [DATA_WIDTH:0] data_in,
        input logic [$clog2(DATA_WIDTH)-1:0] index
    );
        logic [DATA_WIDTH:0] mask = (1 << (index + 1)) - 1;
        return |(data_in & mask);
    endfunction


    reg guard, round, sticky;
    wire  factor_1;
    assign factor_1 = (round | sticky | mantissa_lsb);

    assign round_up = guard & factor_1;
    always_comb begin

        guard  = 0;
        round  = 0;
        sticky = 0;

        if (lsb_index > 0) begin
            guard  = get_bit(data_in, lsb_index-1);
        end
        if (lsb_index > 1) begin
            round  = get_bit(data_in, lsb_index-2);
        end
        if (lsb_index > 2) begin
            sticky = get_sticky(data_in, lsb_index-3);
        end
    end

endmodule
