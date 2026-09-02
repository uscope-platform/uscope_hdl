
module fuzzing_tb_fifo;
    logic clk = 0;
    logic [31:0] dut_in, dut_out;
    int in_file, out_file;
    int status;

    always #5 clk = ~clk;
    assign dut_out = dut_in * 2; // Dummy FPGA DUT logic

    initial begin
        $display("[SV] Simulator started. Waiting for C++ requests...");
        
        forever begin
            // 1. Open FIFO pipes (created in terminal via 'mkfifo')
            in_file = $fopen("in_pipe", "r");   // Blocks until C++ opens for writing
            status = $fscanf(in_file, "%d\n", dut_in);
            $fclose(in_file);

            if (status == 1) begin
                $display("[SV @ %0t] Read input: %0d", $time, dut_in);
                if(dut_in ==666) begin
                    $display("[SV @ %0t] Requested termination", $time);  
                    $finish();
                end
                // 3. Drive FPGA design
                @(posedge clk);
                #1;
                
                // 4. Write output back to C++
                out_file = $fopen("out_pipe", "w"); // Blocks until C++ opens for reading
                $fdisplay(out_file, "%d", dut_out);
                $fflush(out_file);
                $fclose(out_file);
                $display("[SV @ %0t] Sent result: %0d", $time, dut_out);
            end
        end
    end
endmodule