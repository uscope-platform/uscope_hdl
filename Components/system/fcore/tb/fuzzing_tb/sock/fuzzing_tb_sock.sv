module fuzzing_tb_sock;
    logic clk = 0;
    logic [31:0] dut_in, dut_out;
    int status;
    int rx_val;

    always #5 clk = ~clk;
    assign dut_out = dut_in * 2;

    // Import DPI-C C functions
    import "DPI-C" function int init_socket_server();
    import "DPI-C" function int process_transaction(input int out_val, output int in_val);
    import "DPI-C" function void cleanup_socket_server();

    initial begin
        $display("[SV] Starting simulator with DPI-C Sockets...");
        
        if (init_socket_server() != 0) begin
            $display("[SV] Failed to start socket server.");
            $finish;
        end

        forever begin
            // Blocks until client connects and sends data
            status = process_transaction(dut_out, rx_val);
            dut_in = rx_val;

            if (status == 666 || rx_val == 666) begin
                $display("[SV @ %0t] Termination requested (666). Shutting down.", $time);
                cleanup_socket_server();
                $finish;
            end

            $display("[SV @ %0t] Received input: %0d", $time, dut_in);
            
            // Drive design
            @(posedge clk);
            #1;
            
            $display("[SV @ %0t] Output calculated: %0d", $time, dut_out);
        end
    end
endmodule