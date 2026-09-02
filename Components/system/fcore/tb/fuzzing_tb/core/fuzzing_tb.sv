module fuzzing_tb;
    logic clk = 0;
    int status;

    always #5 clk = ~clk;

    typedef struct {
        logic [31:0]   reg_file [64];      // 64 x 32-bit registers
        logic [31:0] instructions [4096
        
        ];  // 4096 x 32-bit instructions
    } fuzzing_package_t;
    

    import "DPI-C" function int init_socket_server();
    import "DPI-C" function int process_transaction(
        output logic [31:0] regs [], 
        output logic [31:0] insts []
    );   
    import "DPI-C" function void cleanup_socket_server();
    
    fuzzing_package_t pkg;

    initial begin
        $display("[SV] Starting simulator with DPI-C Sockets...");
        
        if (init_socket_server() != 0) begin
            $display("[SV] Failed to start socket server.");
            $finish;
        end

        forever begin
            // Blocks until client connects and sends data
            automatic int status = process_transaction(pkg.reg_file, pkg.instructions);
            
            if (pkg.reg_file[0] == 666) begin
                $display("[SV @ %0t] Termination requested (666). Shutting down.", $time);
                cleanup_socket_server();
                $finish;
            end
            $display("[SV @ %0t] Received package!", $time);

            $display(" reg[1]: %d, inst[0]: %d", pkg.reg_file[1], pkg.instructions[0]);
            $display(" reg[2]: %d, inst[1]: %d", pkg.reg_file[2], pkg.instructions[1]);
            $display(" reg[3]: %d, inst[2]: %d", pkg.reg_file[3], pkg.instructions[2]);

        
            // Drive design
            @(posedge clk);
            #1;
        end
    end
endmodule