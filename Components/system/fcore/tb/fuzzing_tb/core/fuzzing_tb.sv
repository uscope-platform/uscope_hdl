module fuzzing_tb;
    import fuzz_server_pkg::*;

    logic clk = 0;
    always #5 clk = ~clk;

    fuzzing_server    server;
    fuzz_package_t current_pkg;
    fuzz_result_t results_pkg;

    initial begin
        server = new();
        
        if (!server.start()) begin
            $finish;
        end
        
        for(int i = 0; i<64; i++)begin
            results_pkg.regs[i] = 0;
        end

        forever begin
            // Clean interface: blocking fetch
            server.get_next_transaction(current_pkg);

            $display("[TB @ %0t] Received valid fuzzing vector!", $time);
            $display("  reg[1]: %0d | inst[0]: %0d", current_pkg.reg_file[1], current_pkg.instructions[0]);
            $display("  reg[2]: %0d | inst[1]: %0d", current_pkg.reg_file[2], current_pkg.instructions[1]);
            $display("  reg[2]: %0d | inst[1]: %0d", current_pkg.reg_file[3], current_pkg.instructions[2]);

            // Drive hardware core interface
            @(posedge clk);
            #1;

            server.send_results(results_pkg)
        end
    end
endmodule