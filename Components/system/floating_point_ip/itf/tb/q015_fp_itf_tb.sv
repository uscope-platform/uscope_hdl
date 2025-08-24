module q015_fp_itf_tb();

    logic clk, rst, in_valid;

    axi_stream dut_in();
    axi_stream dut_out();

    // DUT
    fp_itf #(
        .FIXED_POINT_Q015(1)
    ) dut (
        .clock(clk),
        .reset(rst),
        .in(dut_in),
        .out(dut_out)
    );

    // Clock generator
    initial clk = 0;
    always #5 clk = ~clk;

    // Stimulus
    integer i;
    logic [31:0] expected;
    real ref_real;

    initial begin
        rst = 0;
        dut_in.valid = 0;
        dut_in.data = 0;
        #20 rst = 1;

        // Run through some edge + random cases
        for (i = -32768; i <= 32767; i = i + 2048) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = i[15:0];
        end

        // a few specific edge cases
        @(posedge clk);
        dut_in.data  = 16'sh0000; in_valid = 1; // zero
        @(posedge clk);
        dut_in.data  = 16'sh7FFF; in_valid = 1; // just under +1
        @(posedge clk);
        dut_in.data  = 16'sh8000; in_valid = 1; // exactly -1

        // stop driving inputs
        @(posedge clk);
        dut_in.valid = 0;

        // let pipeline drain
        repeat (20) @(posedge clk);
        $finish;
    end

    logic [15:0] in_delayed[1:0];
    logic [15:0] in_check;

    real in_real;
    real out_real;
    assign out_real = $bitstoshortreal(dut_out.data);
    assign in_real = $signed(in_check) / 32768.0;

    always_ff @(posedge clk) begin
        in_delayed[0] <= dut_in.data;
        in_delayed[1] <= in_delayed[0];
        in_check <= in_delayed[1];
    end
    logic [31:0] check_data;
    assign check_data = $shortrealtobits(in_real);
    
    assert property (@(posedge clk) dut_out.valid |->  dut_out.data[31:0] == check_data[31:0])
    else $error("Q0.15 conversion failed: dut_out.data = %h, expected = %h", dut_out.data, $shortrealtobits(in_real));
    
endmodule