module rounding_engine #(
    parameter DATA_WIDTH = 32
) (
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire mantissa_lsb,
    input  wire [$clog2(DATA_WIDTH)-1:0] msb_index,
    output wire round_up
);


    function automatic logic get_bit (
        input logic [DATA_WIDTH:0] data_in,
        input logic [$clog2(DATA_WIDTH)-1:0] index
    );
        return (data_in >> index) & 1'b1;
    endfunction

    // Function to calculate the sticky bit (OR reduction of all bits below a variable index).
    function automatic logic get_sticky (
        input logic [DATA_WIDTH:0] data_in,
        input logic [$clog2(DATA_WIDTH)-1:0] index
    );
        logic [DATA_WIDTH:0] mask = (1'b1 << index) - 1'b1;
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

        if (msb_index >= 24) begin
            guard = get_bit(data_in, msb_index - 24);
        end

        if (msb_index >= 25) begin
            round = get_bit(data_in, msb_index - 25);
        end

        if (msb_index >= 26) begin
            sticky = get_sticky(data_in, msb_index - 25);
        end
    end

endmodule
