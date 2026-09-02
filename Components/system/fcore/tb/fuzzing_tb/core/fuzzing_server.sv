package fuzz_server_pkg;

    typedef struct {
        logic [31:0] reg_file[64];
        logic [31:0] instructions[4096];
    } fuzz_package_t;

    typedef struct {
        logic [31:0] reg_file[64];
    } fuzz_result_t;

    import "DPI-C" function int init_socket_server();
    import "DPI-C" function int process_transaction(
        output logic [31:0] regs [], 
        output logic [31:0] insts []
    );   
    import "DPI-C" function int process_results(
        input logic [31:0] regs []
    );   
    import "DPI-C" function void cleanup_socket_server();

    class fuzzing_server;
        local bit is_initialized = 0;

        function new();
        endfunction

        function bit start();
            if (is_initialized) return 1;
            
            $display("[fuzzing_server] Starting DPI Socket Server...");
            if (init_socket_server() != 0) begin
                $display("[fuzzing_server] ERROR: Failed to bind socket.");
                return 0;
            end
            
            is_initialized = 1;
            $display("[fuzzing_server] Server online and listening.");
            return 1;
        endfunction

        // Handles transaction retrieval, shutdown detection, and simulation termination
        task get_next_transaction(output fuzz_package_t pkg);
            int status;

            if (!is_initialized) begin
                $fatal(1, "[fuzzing_server] Called get_next_transaction() before start()!");
            end

            status = process_transaction(pkg.reg_file, pkg.instructions);

            // Shutdown check encapsulated directly inside the class
            if (status == 666 || pkg.reg_file[0] == 32'd666) begin
                shutdown();
            end
        endtask

        task send_results(input fuzz_result_t pkg);
            process_results(pkg.reg_file);
        endtask

        // Encapsulated cleanup and termination
        function void shutdown();
            $display("[fuzzing_server @ %0t] Shutdown signal (666) received. Closing socket and exiting simulation.", $time);
            if (is_initialized) begin
                cleanup_socket_server();
                is_initialized = 0;
            end
            $finish; // End simulation directly from class
        endfunction

    endclass

endpackage