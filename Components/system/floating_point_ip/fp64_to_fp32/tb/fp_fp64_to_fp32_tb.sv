module fp_fp64_to_fp32_tb();

    logic clk, rst;

    axi_stream #(.DATA_WIDTH(64)) dut_in();
    axi_stream #(.DATA_WIDTH(32)) dut_out();

    fp_fp64_to_fp32 dut (
        .clock(clk),
        .reset(rst),
        .in(dut_in),
        .out(dut_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    assign dut_out.ready = 1;

    // mostly exponents around the single precision range, so overflow and underflow are hit often,
    // and mantissas that sit on the rounding boundaries, so every rounding case is hit
    function automatic logic [63:0] random_double();
        logic [63:0] value;
        value = {$urandom(), $urandom()};
        case ($urandom_range(0, 7))
            0, 1, 2: value[62:52] = 11'd896 + $urandom_range(0, 260) - 2;
            3: begin
                // infinity or NaN
                value[62:52] = 11'h7FF;
                if ($urandom_range(0, 1)) value[51:0] = 0;
            end
            4: value[62:52] = 11'd0;
            default: ;
        endcase
        case ($urandom_range(0, 5))
            0: value[28:0] = 29'h10000000; // exact tie
            1: value[28:0] = 29'h10000001; // just above the tie
            2: value[28:0] = 29'h0FFFFFFF; // just below the tie
            3: begin
                // rounds up into the next exponent
                value[51:29] = 23'h7FFFFF;
                value[28:0] = 29'h10000000 | $urandom_range(0, 1);
            end
            default: ;
        endcase
        return value;
    endfunction

    integer i;
    initial begin
        rst = 0;
        dut_in.initialize();
        #20 rst = 1;

        for (i = 0; i < 100000; i++) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = random_double();
        end

        @(posedge clk);
        dut_in.valid = 0;
        repeat (5) @(posedge clk);
        $finish;
    end

    // the output is two cycles behind the input
    logic [63:0] in_delayed [1:0];
    always_ff @(posedge clk) begin
        in_delayed[0] <= dut_in.data;
        in_delayed[1] <= in_delayed[0];
    end

    real in_real;
    logic [31:0] expected;
    always_comb begin
        in_real = $bitstoreal(in_delayed[1]);
        expected = $shortrealtobits(in_real);
        // denormal results are flushed to zero
        if (expected[30:23] == 0) expected = {expected[31], 31'b0};
    end

    wire is_nan = in_delayed[1][62:52] == 11'h7FF && in_delayed[1][51:0] != 0;

    assert property (@(posedge clk) dut_out.valid && !is_nan |-> dut_out.data == expected)
    else $error("fp64 to fp32 conversion failed: in = %h, out = %h, expected = %h", in_delayed[1], dut_out.data, expected);

    assert property (@(posedge clk) dut_out.valid && is_nan |-> dut_out.data[30:23] == 8'hFF && dut_out.data[22:0] != 0)
    else $error("fp64 to fp32 conversion lost a NaN: in = %h, out = %h", in_delayed[1], dut_out.data);

    // -----------------------
    // Coverage
    // -----------------------

    typedef enum {CLASS_ZERO, CLASS_UNDERFLOW, CLASS_NORMAL, CLASS_OVERFLOW, CLASS_INFINITY, CLASS_NAN} input_class_t;
    typedef enum {ROUND_DOWN, ROUND_TIE_EVEN, ROUND_TIE_ODD, ROUND_UP} rounding_t;

    wire [63:0] sampled = in_delayed[1];
    wire [10:0] sampled_exponent = sampled[62:52];
    wire [51:0] sampled_mantissa = sampled[51:0];

    function automatic input_class_t classify(input logic [10:0] exponent, input logic [51:0] mantissa);
        if (exponent == 11'h7FF) return mantissa == 0 ? CLASS_INFINITY : CLASS_NAN;
        if (exponent == 11'd0) return CLASS_ZERO;
        if (exponent <= 11'd896) return CLASS_UNDERFLOW;
        if (exponent >= 11'd1151) return CLASS_OVERFLOW;
        return CLASS_NORMAL;
    endfunction

    input_class_t input_class;
    assign input_class = classify(sampled_exponent, sampled_mantissa);

    // guard is the first discarded bit, sticky the OR of the others
    wire guard = sampled_mantissa[28];
    wire sticky = |sampled_mantissa[27:0];
    wire lsb = sampled_mantissa[29];

    rounding_t rounding;
    always_comb begin
        if (!guard) rounding = ROUND_DOWN;
        else if (sticky) rounding = ROUND_UP;
        else rounding = lsb ? ROUND_TIE_ODD : ROUND_TIE_EVEN;
    end

    // the rounding carried into the exponent
    wire rounds_up = guard & (sticky | lsb);
    wire carries = rounds_up && sampled_mantissa[51:29] == 23'h7FFFFF;

    covergroup conversion_cg @(posedge clk iff dut_out.valid);
        option.per_instance = 1;

        class_cp: coverpoint input_class {
            bins zero      = {CLASS_ZERO};
            bins underflow = {CLASS_UNDERFLOW};
            bins normal    = {CLASS_NORMAL};
            bins overflow  = {CLASS_OVERFLOW};
            bins infinity  = {CLASS_INFINITY};
            bins nan       = {CLASS_NAN};
        }

        sign_cp: coverpoint sampled[63];

        rounding_cp: coverpoint rounding iff (input_class == CLASS_NORMAL) {
            bins round_down = {ROUND_DOWN};
            bins tie_even   = {ROUND_TIE_EVEN};
            bins tie_odd    = {ROUND_TIE_ODD};
            bins round_up   = {ROUND_UP};
        }

        carry_cp: coverpoint carries iff (input_class == CLASS_NORMAL) {
            bins no_carry = {0};
            bins carry = {1};
        }

        // the edges of the normal range: the smallest and largest exponent, and rounding that overflows
        exponent_edges_cp: coverpoint sampled_exponent iff (input_class == CLASS_NORMAL || input_class == CLASS_UNDERFLOW || input_class == CLASS_OVERFLOW) {
            bins just_below_normal = {11'd896};
            bins smallest_normal   = {11'd897};
            bins largest_normal    = {11'd1150};
            bins just_above_normal = {11'd1151};
            bins others            = default;
        }

        carry_into_infinity_cp: coverpoint (carries && sampled_exponent == 11'd1150) iff (input_class == CLASS_NORMAL) {
            bins rounds_to_infinity = {1};
            bins other = {0};
        }

        class_x_sign: cross class_cp, sign_cp;
        rounding_x_sign: cross rounding_cp, sign_cp;
    endgroup

    conversion_cg coverage = new();

    final begin
        $display("fp64 to fp32 coverage: %0.2f%%", coverage.get_inst_coverage());
    end

endmodule
