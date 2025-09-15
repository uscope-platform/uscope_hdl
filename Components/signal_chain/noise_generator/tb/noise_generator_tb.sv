`timescale 10ns / 1ns
`include "axi_lite_BFM.svh"
`include "interfaces.svh"

module noise_generator_tb ();


    parameter TEST_FLOAT_MODE = 1;

    reg  clk, reset;

    event config_done;

    axi_lite cfg_axi();
    axi_lite_BFM axil_bfm;

    parameter OUTPUT_WIDTH = TEST_FLOAT_MODE ? 32 : 16;

    axi_stream #(.DATA_WIDTH(OUTPUT_WIDTH)) data_out();


    reg trigger = 1'b0;

    always begin
        trigger = 1'b0;
        #23 trigger = 1'b1;
        #1;
    end

    noise_generator #(
        .OUTPUT_WIDTH(16),
        .FLOAT_OUT(TEST_FLOAT_MODE)
    )gen(
        .clock(clk),
        .reset(reset),
        .trigger(trigger),
        .axi_in(cfg_axi),
        .data_out(data_out)
    );


    int results_file;

    if(TEST_FLOAT_MODE) begin
        shortreal converted_out;
        assign converted_out = $bitstoshortreal(data_out.data);
        initial begin
            results_file = $fopen("/home/fils/git/uscope_hdl/public/Components/signal_chain/noise_generator/tb/results_fp.csv", "w");
        end

        always_ff @(posedge data_out.valid)begin
            $fwrite(results_file, "%f\n", converted_out);
            $fflush(results_file);
        end


    end else begin

        initial begin
            results_file = $fopen("/home/fils/git/uscope_hdl/public/Components/signal_chain/noise_generator/tb/results.csv", "w");
        end

        always_ff @(posedge data_out.valid)begin
            $fwrite(results_file, "%0d\n", $signed(data_out.data[15:0]));
        end


    end

    always begin
        clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5;
    end


    initial begin

        data_out.ready <= 1'b0;
        axil_bfm = new(cfg_axi, 1);
        //Initial status
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;

        #50;
        data_out.ready <= 1'b1;

        axil_bfm.write(0, 3);

        axil_bfm.write(4, 7);
        axil_bfm.write(8, 'h10007);
        axil_bfm.write(12,'h20007);

        ->config_done;
    end


endmodule
