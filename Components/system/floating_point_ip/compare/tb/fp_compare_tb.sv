module fp_compare_tb();

    logic clk, rst;

    axi_stream dut_in_a();
    axi_stream dut_in_b();
    axi_stream #(.DATA_WIDTH(32)) dut_out();

    reg [1:0][31:0] stimulus[10000001:0];

    initial begin
        $readmemh("/home/filssavi/git/uplatform-hdl/public/Components/system/floating_point_ip/compare/tb/test_stimuli.mem", stimulus);
    end

    fp_compare dut (
        .clock(clk),
        .in_a(dut_in_a),
        .in_b(dut_in_b),
        .out(dut_out)
    );

    // Clock generator
    initial clk = 0;
    always #0.5 clk = ~clk;

    integer i;
    shortreal test_real;

    initial begin
        rst = 0;
        dut_in_a.valid = 0;
        dut_in_a.data = 0;
        dut_in_b.valid = 0;
        dut_in_b.data = 0;
        #20.5 rst = 1;

        // TEST STEP 1: make shure various special values are handled correctly

        #1
        // quiet NaN != NaN
        dut_in_a.data <= 'h7FC00000;
        dut_in_b.data <= 'h7FC00000;
        dut_in_a.valid = 1;
        dut_in_b.valid = 1;
        #1
        // quiet NaN != signaling NaN
        dut_in_a.data <= 'h7FC00000;
        dut_in_b.data <= 'h7FA00000;
        #1
        // signaling NaN != signaling NaN
        dut_in_a.data <= 'h7F800001;
        dut_in_b.data <= 'h7FBFFFFF;
        #1
        // 0 comparison
        dut_in_a.data <=0;
        dut_in_b.data <= 0;
        #1
        // +0 == -0
        dut_in_a.data <=0;
        dut_in_b.data <= 'h80000000;
        #1
        // +∞ == +∞
        dut_in_a.data <= 'h7F800000;
        dut_in_b.data <= 'h7F800000;
        #1
        // -∞ == -∞
        dut_in_a.data <= 'hFF800000;
        dut_in_b.data <= 'hFF800000;
        #1
        // +∞ > -∞
        dut_in_a.data <= 'h7F800000;
        dut_in_b.data <= 'hFF800000;
        #1
        // +∞ > +34.5
        dut_in_a.data <= 'h7F800000;
        dut_in_b.data <= $shortrealtobits(34.5);
        #1
        //-∞ < +34.5
        dut_in_a.data <= 'hFF800000;
        dut_in_b.data <= $shortrealtobits(34.5);

        #1
        // +∞ > +-4.5
        dut_in_a.data <= 'h7F800000;
        dut_in_b.data <= $shortrealtobits(-34.5);
        #1
        //-∞ < -34.5
        dut_in_a.data <= 'hFF800000;
        dut_in_b.data <= $shortrealtobits(-34.5);

        for(i = 0; i<10000000; i++)begin
            #1 dut_in_a.data <= stimulus[i][1];
            dut_in_b.data <= stimulus[i][0];
        end
        // let pipeline drain
        repeat (20) @(posedge clk);
        $finish;
    end

    reg [31:0] in_a_dly[2:0];
    reg [31:0] in_b_dly[2:0];
    reg [31:0] in_valid_dly[2:0];

    always_ff@(posedge clk) begin
        in_valid_dly[0] <= dut_in_a.valid;
        in_valid_dly[1] <= in_valid_dly[0];
        in_valid_dly[2] <= in_valid_dly[1];

        in_a_dly[0] <= dut_in_a.data;
        in_a_dly[1] <= in_a_dly[0];
        in_a_dly[2] <= in_a_dly[1];

        in_b_dly[0] <= dut_in_b.data;
        in_b_dly[1] <= in_b_dly[0];
        in_b_dly[2] <= in_b_dly[1];
    end

    shortreal a_real, b_real;
    integer out_check;

    assign a_real = $bitstoshortreal(in_a_dly[1]);
    assign b_real = $bitstoshortreal(in_b_dly[1]);


    always @(posedge clk) begin
        if(in_valid_dly[1]) begin
            if(is_nan(in_a_dly[1]) || is_nan(in_b_dly[1])) out_check<= 3;
            else if(a_real > b_real) out_check <= 1;
            else if(a_real < b_real) out_check <=  2;
            else out_check <= 0.0;
        end
        if (dut_out.valid) begin
            assert (dut_out.data == out_check) else begin
                $error("FP_COMPARE MISMATCH: a=%f  b=%f expected=%0d got=%0d",
                            $bitstoshortreal(in_a_dly[2]), $bitstoshortreal(in_b_dly[2]), out_check, dut_out.data);
                $finish();
            end
        end
    end

    function bit is_nan(int val);
        return ((val[30:23] == 8'hFF) && (val[22:0] != 0));
    endfunction

endmodule


