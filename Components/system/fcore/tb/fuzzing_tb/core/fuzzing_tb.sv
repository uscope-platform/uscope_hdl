module fuzzing_tb;
    import fuzz_server_pkg::*;

    logic clock, reset, run, efi_start;

    fuzzing_server    server;
    fuzz_package_t current_pkg;
    fuzz_result_t results_pkg;

    axi_stream efi_arguments();
    axi_stream efi_results();
    axi_lite axi_master();
    AXI axi_programmer();

    axi_stream axis_dma_write();
    axi_stream dma_read_request();
    axi_stream dma_read_response();
    
    event core_ready;
    initial begin
        run = 0;
        axi_programmer.initialize();
        server = new();
        
        if (!server.start()) begin
            $finish;
        end
        
        for(int i = 0; i<64; i++)begin
            results_pkg.reg_file[i] = 32'hDEADBEEF;
        end
        @(core_ready);
        forever begin
            // Clean interface: blocking fetch
            server.get_next_transaction(current_pkg);


            for(int i = 0; i<4096; i++)begin
                #5 axi_programmer.write(i*4, current_pkg.instructions[i]);
            end

            for(int i = 0; i<64; i++)begin
                #5 axi_programmer.write((i+4096)*4, current_pkg.reg_file[i]);
            end

            // Drive hardware core interface
            @(posedge clock);
            #1;
            
            server.send_results(results_pkg);
        end
    end


    initial clock = 0;
    always #0.5 clock = ~clock;
    initial begin
        reset <=0;
        #10.5;
        #20.5 reset <=1;
        #40;
        ->core_ready;
    end

    fCore #(
        .FAST_DEBUG("TRUE"),
        .MAX_CHANNELS(9),
        .RECIPROCAL_PRESENT(1),
        .BITMANIP_IMPLEMENTED(1),
        .LOGIC_IMPLEMENTED(1),
        .EFI_IMPLEMENTED(1),
        .FULL_COMPARE(1),
        .CONDITIONAL_SELECT_IMPLEMENTED(1),
        .ENABLE_DEBUG_INTERFACE("TRUE")
    ) uut(
        .clock(clock),
        .axi_clock(clock),
        .reset(reset),
        .reset_axi(reset),
        .run(run),
        .done(done),
        .efi_start(efi_start),
        .control_axi_in(axi_master),
        .axi(axi_programmer),
        .axis_dma_write(axis_dma_write),
        .axis_dma_read_request(dma_read_request),
        .axis_dma_read_response(dma_read_response),
        .efi_arguments(efi_arguments),
        .efi_results(efi_results)
    );

endmodule