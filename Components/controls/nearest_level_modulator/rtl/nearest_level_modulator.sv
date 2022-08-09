`timescale 10ns / 1ns
`include "interfaces.svh"

module nearest_level_modulator #(
    parameter N_CELLS = 10
)(
    input wire clock,
    input wire reset,
    input wire start,
    axi_stream.slave data_in
);

    reg [31:0] cell_voltages[N_CELLS-1:0];
    reg [N_CELLS-1:0] cell_states;

    axi_stream sorter_in();
    axi_stream sorter_out();

    merge_sorter #(
        .DATA_WIDTH(16),
        .DEST_WIDTH(16),
        .USER_WIDTH(16),
        .MAX_SORT_LENGTH(256)
    )sorting_core(
        .clock(clock),
        .reset(reset),
        .start(start),
        .data_length(data_length),
        .input_data(sorter_in),
        .output_data(sorter_out)
    );

    reg [$clog2(N_CELLS)-1:0] read_counter;

    enum logic [1:0] { 
        idle_state = 0,
        read_s_state = 1,
        read_voltages_state = 2,
        modulate_state = 3
    } modulator_fsm = idle_state;
    
    always_ff @(posedge clock) begin
        case(modulator_fsm)
        idle_state:begin
            if(start) begin
                modulator_fsm <= read_s_state;
                read_counter <= 0;
            end
        end
        read_s_state:begin
            if(data_in.valid)begin
                cell_states[read_counter] <= data_in.data[read_counter];
                modulator_fsm <= modulate_state;
            end
        end
        read_voltages_state:begin
            if(read_counter == N_CELLS)begin
                read_counter <= 0;
            end else begin
                cell_voltages[read_counter] <= data_in.data;
                read_counter <= read_counter+1;
            end
        end
        modulate_state:begin
        end
        endcase
    end

endmodule