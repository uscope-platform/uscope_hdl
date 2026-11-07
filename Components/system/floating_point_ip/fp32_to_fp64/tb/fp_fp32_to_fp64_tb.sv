module fp_fp32_to_fp64_tb();

    logic clk, rst;

    axi_stream #(.DATA_WIDTH(32)) dut_in();
    axi_stream #(.DATA_WIDTH(64)) dut_out();

    fp_fp32_to_fp64 dut (
        .clock(clk),
        .reset(rst),
        .in(dut_in),
        .out(dut_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    assign dut_out.ready = 1;

    // plain random words are almost never denormal, infinite or NaN, so those are generated on purpose
    function automatic logic [31:0] random_single();
        logic [31:0] value;
        value = $urandom();
        case ($urandom_range(0, 7))
            0, 1: begin
                // zero or denormal, with every position of the leading one
                value[30:23] = 0;
                value[22:0] = value[22:0] >> $urandom_range(0, 22);
            end
            2: begin
                // infinity or NaN
                value[30:23] = 8'hFF;
                if ($urandom_range(0, 1)) value[22:0] = 0;
            end
            3: begin
                // edges of the normal range
                value[30:23] = $urandom_range(0, 1) ? 8'h01 : 8'hFE;
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
            dut_in.data  = random_single();
        end

        @(posedge clk);
        dut_in.valid = 0;
        repeat (5) @(posedge clk);
        $finish;
    end

    // the output is two cycles behind the input
    logic [31:0] in_delayed_0;
    logic [31:0] in_delayed;
    always_ff @(posedge clk) begin
        in_delayed_0 <= dut_in.data;
        in_delayed <= in_delayed_0;
    end

    real expected_real;
    logic [63:0] expected;
    always_comb begin
        expected_real = $bitstoshortreal(in_delayed);
        expected = $realtobits(expected_real);
    end

    // NaNs are only checked to still be NaNs
    wire is_nan = in_delayed[30:23] == 8'hFF && in_delayed[22:0] != 0;

    assert property (@(posedge clk) dut_out.valid && !is_nan |-> dut_out.data == expected)
    else $error("fp32 to fp64 conversion failed: in = %h, out = %h, expected = %h", in_delayed, dut_out.data, expected);

    assert property (@(posedge clk) dut_out.valid && is_nan |-> dut_out.data[62:52] == 11'h7FF && dut_out.data[51:0] != 0)
    else $error("fp32 to fp64 conversion lost a NaN: in = %h, out = %h", in_delayed, dut_out.data);

    // -----------------------
    // Coverage
    // -----------------------

    typedef enum {CLASS_ZERO, CLASS_DENORMAL, CLASS_NORMAL, CLASS_INFINITY, CLASS_NAN} input_class_t;

    function automatic input_class_t classify(input logic [31:0] value);
        if (value[30:23] == 8'h00) return value[22:0] == 0 ? CLASS_ZERO : CLASS_DENORMAL;
        if (value[30:23] == 8'hFF) return value[22:0] == 0 ? CLASS_INFINITY : CLASS_NAN;
        return CLASS_NORMAL;
    endfunction

    // position of the leading one in the mantissa
    function automatic integer msb_index(input logic [22:0] value);
        integer index = 0;
        for (integer bit_index = 0; bit_index < 23; bit_index++)
            if (value[bit_index]) index = bit_index;
        return index;
    endfunction

    input_class_t input_class;
    assign input_class = classify(in_delayed);

    integer denormal_msb;
    assign denormal_msb = msb_index(in_delayed[22:0]);

    covergroup conversion_cg @(posedge clk iff dut_out.valid);
        option.per_instance = 1;

        class_cp: coverpoint input_class {
            bins zero     = {CLASS_ZERO};
            bins denormal = {CLASS_DENORMAL};
            bins normal   = {CLASS_NORMAL};
            bins infinity = {CLASS_INFINITY};
            bins nan      = {CLASS_NAN};
        }

        sign_cp: coverpoint in_delayed[31];

        // every normalization shift the denormal path can take
        denormal_msb_cp: coverpoint denormal_msb iff (input_class == CLASS_DENORMAL) {
            bins msb[] = {[0:22]};
        }

        exponent_edges_cp: coverpoint in_delayed[30:23] iff (input_class == CLASS_NORMAL) {
            bins smallest = {8'h01};
            bins largest  = {8'hFE};
            bins others   = default;
        }

        class_x_sign: cross class_cp, sign_cp;
    endgroup

    conversion_cg coverage = new();

    final begin
        $display("fp32 to fp64 coverage: %0.2f%%", coverage.get_inst_coverage());
    end

endmodule
