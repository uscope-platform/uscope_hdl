`timescale 10ns / 1ns
`include "interfaces.svh"
`include "axis_BFM.svh"

module nearest_level_modulator_tb ();

    reg clock, reset, start;

    axi_stream #(.DATA_WIDTH(32), .DEST_WIDTH(8), .USER_WIDTH(8)) data_in();    

    axis_BFM#(32, 8, 8) in_bfm;
        

    nearest_level_modulator #(
        .N_CELLS(10)
    )UUT(
        .clock(clock),
        .reset(reset),
        .start(start),
        .data_in(data_in)
    );

    int states_fd;


    initial clock = 0;
    always #0.5 clock = ~clock;

    reg [31:0] data;
    string str;
    int num;
    realtime timebase;

    initial begin
        reset = 0;
        start = 0;
        in_bfm = new(data_in, 1);
        #20 reset = 0;
        #0.5;
        #20 reset = 1;

        if ((states_fd=$fopen("/home/fils/git/uscope_hdl/public/Components/controls/nearest_level_modulator/tb/data/states_a.csv", "r")) == 0) begin
            $display("-------------------------------------------------------------------------------------");
            $display("                      ERROR INPUT STATES FILE NOT FOUND");
            $display("-------------------------------------------------------------------------------------");
            $finish;
        end

        while($fgets(str,states_fd) != 0) begin
            $display(str);
            $sscanf(str, "%f,%d", timebase, num);
            data <= num;
            #10;
        end

    end

endmodule