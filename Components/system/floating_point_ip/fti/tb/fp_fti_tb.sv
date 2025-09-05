module fp_fti_tb();

    logic clk, rst, in_valid;

    axi_stream dut_in();
    axi_stream #(.DATA_WIDTH(32)) dut_out();

    // DUT
    fp_fti  #(
        .FIXED_POINT_Q015(0)
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
    shortreal test_real;

    initial begin
        rst = 0;
        dut_in.valid = 0;
        dut_in.data = 0;
        #20 rst = 1;

        dut_in.valid = 1;
        // a few specific edge cases


        // Run through some edge + random cases
        for (i =0 ; i <= 32768; i++) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = $shortrealtobits($itor(i));
        end
        $display("-------ROUND 1 COMPLETE--------");
        #10;
        // Run through some edge + random cases
        for (i =0 ; i >= -32768; i--) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = $shortrealtobits($itor(i));
        end
        $display("-------ROUND 2 COMPLETE--------");
        // Run through some edge + random cases
        for (i =0; i <= 250000; i++) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = $shortrealtobits($itor(16718748+i));
        end
        $display("-------ROUND 3 COMPLETE--------");
        // Run through some edge + random cases
        for (i =0; i <= 250000; i++) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = $shortrealtobits($itor(33554411+i));
        end
        $display("-------ROUND 4 COMPLETE--------");
        
        for (i =0; i <= 250000; i++) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = $shortrealtobits($itor(67070430+i));
        end
        
        $display("-------ROUND 5 COMPLETE--------");
        for (i =0; i <= 250000; i++) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = $shortrealtobits($itor(-16718748-i));
        end
        $display("-------ROUND 6 COMPLETE--------");

                // Run through some edge + random cases
        for (i =0; i <= 250000; i++) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = $shortrealtobits($itor(-33554411-i));
        end

        $display("-------ROUND 7 COMPLETE--------");
                // Run through some edge + random cases
        for (i =0; i <= 250000; i++) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = $shortrealtobits($itor(-67070430-i));
        end

        $display("-------ROUND 8 COMPLETE--------");
        // Run through some edge + random cases
        for (i =0; i <= 400000; i++) begin
            @(posedge clk);
            dut_in.valid = 1;
            dut_in.data  = $shortrealtobits($itor(2147083647+i));
        end

        $display("-------ROUND 9 COMPLETE--------");




        // stop driving inputs
        @(posedge clk);
        dut_in.valid = 0;

        #100;
        
        // Start testing edge cases

        #1 dut_in.valid = 1; dut_in.data = 32'h00000000; // +0
        #1 dut_in.valid = 1; dut_in.data = 32'h80000000; // -0
        #1 dut_in.valid = 1; dut_in.data = 32'h00000001; // smallest subnormal

        test_real = 0.1;
        #1 dut_in.valid = 1; dut_in.data = $shortrealtobits(test_real);
        test_real = 0.4;
        #1 dut_in.valid = 1; dut_in.data = $shortrealtobits(test_real);
        test_real = 0.5;
        #1 dut_in.valid = 1; dut_in.data = $shortrealtobits(test_real);
        test_real = 0.6;
        #1 dut_in.valid = 1; dut_in.data = $shortrealtobits(test_real);
        test_real = 1.2;
        #1 dut_in.valid = 1; dut_in.data = $shortrealtobits(test_real);
        test_real = 2;
        #1 dut_in.valid = 1; dut_in.data = $shortrealtobits(test_real);
        test_real = 2.4;
        #1 dut_in.valid = 1; dut_in.data = $shortrealtobits(test_real);
        test_real = 2.5;
        #1 dut_in.valid = 1; dut_in.data = $shortrealtobits(test_real);
        test_real = 3.5;
        #1 dut_in.valid = 1; dut_in.data = $shortrealtobits(test_real);
        test_real = 2.6;
        #1 dut_in.valid = 1; dut_in.data = $shortrealtobits(test_real);
        test_real = 3;
        #1 dut_in.valid = 1; dut_in.data = $shortrealtobits(test_real);
    
        

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
    assign in_real = $bitstoshortreal(in_check);

    integer check_data;
    assign check_data = $rtoi(in_real);


    always_ff @(posedge clk) begin
        if (dut_out.valid) begin
            assert ($signed(dut_out.data) == check_data)
            else begin
                $display("==============================================================================");
                $display("CONVERSION FAILED at time %t", $time);
                $display(" -> Input:   %h (%f)", in_check, in_real);
                $display(" -> DUT Out: %d", dut_out.data);
                $display(" -> Expected:  %d", check_data);
                $display("==============================================================================");
                $finish();
            end
        end
    end

   
endmodule