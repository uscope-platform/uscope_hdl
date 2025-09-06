module fp_fti_tb_py();

    logic clk, rst, in_valid;

    axi_stream dut_in();
    axi_stream #(.DATA_WIDTH(32)) dut_out();

    reg [31:0] stimulus[999999:0];
    reg [31:0] results[999999:0];

    initial begin
        $readmemh("/home/fils/git/uscope_hdl/public/Components/system/floating_point_ip/fti/tb/test_stimuli.mem", stimulus);
        $readmemh("/home/fils/git/uscope_hdl/public/Components/system/floating_point_ip/fti/tb/test_results.mem", results);
    end

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

    integer i;
    shortreal test_real;

    initial begin
        rst = 0;
        dut_in.valid = 0;
        dut_in.data = 0;
        #20 rst = 1;

         
        for(i = 0; i<1000000; i++)begin
            #1 dut_in.data <= stimulus[i]; dut_in.valid = 1;
        end
        // let pipeline drain
        repeat (20) @(posedge clk);
        $finish;
    end

    reg[31:0] output_counter = 0;

    always_ff @(posedge clk) begin
        if(dut_out.valid)begin
            if(dut_out.data !== results[output_counter]) begin
                $display("Mismatch at %0d: got %h, expected %h", output_counter, dut_out.data, results[output_counter]);
                $fatal;
            end
            output_counter <= output_counter + 1;
        end
    end
   
endmodule

