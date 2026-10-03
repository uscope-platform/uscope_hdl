module CORDIC_core#(
    parameter integer RESOLUTION = 16,
    parameter integer GUARD_BITS = 3
)(
    input wire clock,
    input wire reset,
    axi_stream.slave initial_condition,
    axi_stream.master out
);



   assign initial_condition.ready = out.ready && state == idle_state;
   

    reg [$clog(RESOLUTION)-1:0] step_counter = 0;
    reg [RESOLUTION + GUARD_BITS-1:0] x_int;
    reg [RESOLUTION + GUARD_BITS-1:0] y_int;
    reg [RESOLUTION + GUARD_BITS-1:0] z_int;


    enum reg [1:0] { 
        idle_state,
        processing_state
    } state = idle_state;

    always_ff @(posedge clock) begin
        case (state)
            idle_state: begin
                if (initial_condition.valid && initial_condition.ready) begin
                    state <= processing_state;
                    x_int <= initial_condition.data[15:0];
                    y_int <= initial_condition.data[31:0];
                    z_int <= initial_condition.user;
                    step_counter <= 0;
                end
            end 
            processing_state: begin
                if(step_counter == RESOLUTION)begin
                    state <= idle_state;
                end else begin
                    // TODO: IMPLEMENT THE CORE CORDIC LOOP
                    step_counter <= step_counter + 1;
                end
            end 
        endcase
    end

endmodule