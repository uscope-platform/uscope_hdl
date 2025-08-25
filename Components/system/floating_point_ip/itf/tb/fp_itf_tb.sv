module fp_itf_tb();

    logic clk, rst, in_valid;

    axi_stream dut_in();
    axi_stream dut_out();

    // DUT
    fp_itf  #(
        .FIXED_POINT_Q015(0),
        .INPUT_WIDTH(32)
    ) dut (
        .clock(clk),
        .reset(rst),
        .in(dut_in),
        .out(dut_out)
    );

    // Clock generator
    initial clk = 0;
    always #0.5 clk = ~clk;

    // Stimulus
    integer i;
    logic [31:0] expected;
    real ref_real;

    initial begin
        rst = 0;
        dut_in.valid = 0;
        dut_in.data = 0;
        #20 rst = 1;

        dut_in.valid = 1;
        // a few specific edge cases


        // Run through some edge + random cases
        for (i = -32768; i <= 32768; i++) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = i;
        end

        // Run through some edge + random cases
        for (i =0; i <= 250000; i++) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = 16718748+i;
        end

        // Run through some edge + random cases
        for (i =0; i <= 250000; i++) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = 33554411+i;
        end

                // Run through some edge + random cases
        for (i =0; i <= 250000; i++) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = 67070430+i;
        end
        
        for (i =0; i <= 250000; i++) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = -16718748-i;
        end

                // Run through some edge + random cases
        for (i =0; i <= 250000; i++) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = -33554411-i;
        end

                // Run through some edge + random cases
        for (i =0; i <= 250000; i++) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = -67070430-i;
        end


        // stop driving inputs
        @(posedge clk);
        dut_in.valid = 0;

        // let pipeline drain
        repeat (20) @(posedge clk);
        $finish;
    end

    logic [31:0] in_delayed[1:0];
    logic [31:0] in_check;


    always_ff @(posedge clk) begin
        in_delayed[0] <= dut_in.data;
        in_delayed[1] <= in_delayed[0];
        in_check     <= in_delayed[1];
    end

    real in_real;
    assign in_real = $signed(in_check);


    logic [31:0] check_data;
    assign check_data = $shortrealtobits(in_real);
        


    always_ff @(posedge clk) begin
        if (dut_out.valid) begin
                assert (dut_out.data == check_data)
                else begin
                    $display("==============================================================================");
                    $display("CONVERSION FAILED at time %t", $time);
                    $display(" -> Input:   %d (%h)", $signed(in_check), in_check);
                    $display(" -> DUT Out: %h (%f)", dut_out.data, $bitstoshortreal(dut_out.data));
                    $display(" -> Expected:  %h (%f)", check_data, in_real);
                    $display("==============================================================================");
                    $finish();
                end
        end
    end

endmodule