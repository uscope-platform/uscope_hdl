module fp_compare_tb();

    logic clk, rst, in_valid;

    axi_stream dut_in_a();
    axi_stream dut_in_b();
    axi_stream #(.DATA_WIDTH(32)) dut_out();

    reg [1:0][31:0] stimulus[100:0];
    reg [31:0] results[100:0];

    initial begin
        $readmemh("/home/fils/git/uscope_hdl/public/Components/system/floating_point_ip/compare/tb/test_stimuli.mem", stimulus);
        $readmemh("/home/fils/git/uscope_hdl/public/Components/system/floating_point_ip/compare/tb/test_results.mem", results);
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


        for(i = 0; i<10000000; i++)begin
            #1 dut_in_a.data <= stimulus[i][1]; dut_in_a.valid = 1;
            dut_in_b.data <= stimulus[i][0]; dut_in_b.valid = 1;
        end
        // let pipeline drain
        repeat (20) @(posedge clk);
        $finish;
    end

    reg [31:0] in_a_dly[1:0];
    reg [31:0] in_b_dly[1:0];

    always_ff@(posedge clk) begin
        in_a_dly[0] <= dut_in_a.data;
        in_a_dly[1] <= in_a_dly[0];

        in_b_dly[0] <= dut_in_b.data;
        in_b_dly[1] <= in_b_dly[0];
    end
    
    shortreal a_real, b_real, out_real;

    always_ff@(posedge clk) begin
        if(dut_out.valid) begin
            a_real = $bitstoshortreal(in_a_dly[1]);
            b_real = $bitstoshortreal(in_b_dly[1]);
            if(a_real > b_real) out_real = 2'b10;
            else if(a_real < b_real) out_real =  2'b01;
            else out_real = 0.0;
        end
    end

endmodule


