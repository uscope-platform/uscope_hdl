module fp_add_tb();

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

    fp_add dut (
        .clock(clk),
        .in_a(dut_in_a),
        .in_b(dut_in_b),
        .out(dut_out)
    );

    // Clock generator
    initial clk = 0;
    always #0.5 clk = ~clk;

   

endmodule


