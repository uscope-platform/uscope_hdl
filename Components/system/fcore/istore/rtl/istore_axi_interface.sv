// Copyright 2024 Filippo Savi
// Author: Filippo Savi <filssavi@gmail.com>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`timescale 10ns / 1ns
module istore_axi_if # (
    parameter integer DATA_WIDTH = 32,
    parameter integer ADDR_WIDTH = 12,
    parameter ENABLE_DEBUG_INTERFACE = "FALSE"
)(
    input wire clock_in,
    input wire reset_in,
    input wire [DATA_WIDTH-1:0] read_data,
    output wire [DATA_WIDTH-1:0] write_data,
    output wire [ADDR_WIDTH-1:0] write_address,
    output wire [ADDR_WIDTH-1:0] read_address,
    output wire write_enable,
    AXI.slave axi,
    fcore_debug_if.master debug_if
);

    reg debug_write_en, debug_read_en;
    reg [31:0] debug_read_data = 0;

    // AXI SPECIFIC SIGNALS
    reg [ADDR_WIDTH-1 : 0] axi_awaddr;
    reg [ADDR_WIDTH : 0] axi_word_address_w;
    reg [ADDR_WIDTH : 0] axi_word_address_r;
    reg [ADDR_WIDTH-1 : 0] axi_araddr;

    wire aw_wrap_en;
    wire ar_wrap_en;
    wire [31:0] aw_wrap_size; 
    wire [31:0] ar_wrap_size; 
    reg axi_awv_awr_flag;
    reg axi_arv_arr_flag; 
    reg [ADDR_WIDTH-1:0] axi_awlen_cntr;
    reg [ADDR_WIDTH-1:0] axi_arlen_cntr;
    reg [1:0] axi_arburst;
    reg [1:0] axi_awburst;
    reg [ADDR_WIDTH:0] axi_arlen;
    reg [ADDR_WIDTH:0] axi_awlen;

    localparam integer ADDR_LSB = (DATA_WIDTH/32) + 1;
    localparam integer OPT_MEM_ADDR_BITS = 7;
    localparam integer USER_NUM_MEM = 100;

    assign axi.BID = axi.AWID;
    assign axi.RID = axi.ARID;
    assign aw_wrap_size = (DATA_WIDTH/8 * (axi_awlen)); 
    assign ar_wrap_size = (DATA_WIDTH/8 * (axi_arlen)); 
    assign aw_wrap_en = ((axi_awaddr & aw_wrap_size) == aw_wrap_size)? 1'b1: 1'b0;
    assign ar_wrap_en = ((axi_araddr & ar_wrap_size) == ar_wrap_size)? 1'b1: 1'b0;

    //-----------------------------------------------------------------
    // WRITE PATH logic
    //-----------------------------------------------------------------
    always @(posedge clock_in) begin : axi_awready_generation
        if (reset_in == 1'b0) begin
            axi.AWREADY <= 1'b0;
            axi_awv_awr_flag <= 1'b0;
        end else begin    
            if (~axi.AWREADY && axi.AWVALID && ~axi_awv_awr_flag && ~axi_arv_arr_flag) begin
                axi.AWREADY <= 1'b1;
                axi_awv_awr_flag  <= 1'b1; 
            end else if (axi.WLAST && axi.WREADY) begin
                axi_awv_awr_flag  <= 1'b0;
            end else begin
                axi.AWREADY <= 1'b0;
            end
        end 
    end     

    assign axi_word_address_w = axi.AWADDR >> 2;

    always @(posedge clock_in) begin : write_address_latching
        if (reset_in == 1'b0) begin
            axi_awaddr <= 0;
            axi_awlen_cntr <= 0;
            axi_awburst <= 0;
            axi_awlen <= 0;
            debug_write_en <= 0;
        end else begin    
            if (~axi.AWREADY && axi.AWVALID && ~axi_awv_awr_flag) begin
                axi_awaddr <= axi_word_address_w[ADDR_WIDTH - 1:0];
                debug_write_en <= axi_word_address_w[ADDR_WIDTH];
                axi_awburst <= axi.AWBURST; 
                axi_awlen <= axi.AWLEN;     
                axi_awlen_cntr <= 0;
            end else if ((axi_awlen_cntr <= axi_awlen) && axi.WREADY && axi.WVALID) begin
                axi_awlen_cntr <= axi_awlen_cntr + 1;
                case (axi_awburst)
                    2'b00: begin // fixed burst
                        axi_awaddr <= axi_awaddr;          
                    end   
                    2'b01: begin // incremental burst
                        axi_awaddr <= axi_awaddr + 1;
                    end   
                    2'b10: begin // Wrapping burst
                        if (aw_wrap_en) begin
                            axi_awaddr <= (axi_awaddr - aw_wrap_size); 
                        end else begin
                            axi_awaddr[ADDR_WIDTH - 1:ADDR_LSB] <= axi_awaddr[ADDR_WIDTH - 1:ADDR_LSB] + 1;
                            axi_awaddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}}; 
                        end
                    end                      
                    default: begin // reserved
                        axi_awaddr <= axi_awaddr[ADDR_WIDTH - 1:ADDR_LSB] + 1;
                    end
                endcase              
            end
        end 
    end       

    always @(posedge clock_in) begin : wready_generation
        if (reset_in == 1'b0) begin
            axi.WREADY <= 1'b0;
        end else begin    
            if (~axi.WREADY && axi.WVALID && axi_awv_awr_flag) begin
                axi.WREADY <= 1'b1;
            end else if (axi.WLAST && axi.WREADY) begin
                axi.WREADY <= 1'b0;
            end
        end 
    end       
    
    always @(posedge clock_in) begin : write_response_generation
        if (reset_in == 1'b0) begin
            axi.BVALID <= 0;
            axi.BRESP <= 2'b0;
            axi.BUSER <= 0;
        end else begin    
            if (axi_awv_awr_flag && axi.WREADY && axi.WVALID && ~axi.BVALID && axi.WLAST) begin
                axi.BVALID <= 1'b1;
                axi.BRESP  <= 2'b0; 
            end else begin
                if (axi.BREADY && axi.BVALID) begin
                    axi.BVALID <= 1'b0; 
                end  
            end
        end
    end   

    //-----------------------------------------------------------------
    // READ PATH LOGIC (Fixed Read State Machine)
    //-----------------------------------------------------------------
    typedef enum logic [1:0] {
        R_IDLE,
        R_WAIT_LATENCY,
        R_DATA_PHASE
    } read_state_e;

    read_state_e r_state;

    assign axi_word_address_r = axi.ARADDR >> 2;

    // ARREADY Generation
    always @(posedge clock_in) begin : read_address_ready_generation
        if (reset_in == 1'b0) begin
            axi.ARREADY <= 1'b0;
            axi_arv_arr_flag <= 1'b0;
        end else begin    
            if (~axi.ARREADY && axi.ARVALID && ~axi_awv_awr_flag && ~axi_arv_arr_flag) begin
                axi.ARREADY <= 1'b1;
                axi_arv_arr_flag <= 1'b1;
            end else if (r_state == R_DATA_PHASE && axi.RVALID && axi.RREADY && (axi_arlen_cntr == axi_arlen)) begin
                axi.ARREADY <= 1'b0;
                axi_arv_arr_flag <= 1'b0;
            end else begin
                axi.ARREADY <= 1'b0;
            end
        end 
    end     

    // Read Address Latching & Burst Counter
    always @(posedge clock_in) begin: read_address_latching
        if (reset_in == 1'b0) begin
            axi_araddr <= 0;
            axi_arlen_cntr <= 0;
            axi_arburst <= 0;
            debug_read_en <= 0;
            axi_arlen <= 0;
            axi.RUSER <= 0;
        end else begin    
            if (~axi.ARREADY && axi.ARVALID && ~axi_arv_arr_flag) begin
                axi_araddr <= axi_word_address_r[ADDR_WIDTH - 1:0]; 
                debug_read_en <= axi_word_address_r[ADDR_WIDTH];
                axi_arburst <= axi.ARBURST; 
                axi_arlen <= axi.ARLEN;     
                axi_arlen_cntr <= 0;
            end else if (axi.RVALID && axi.RREADY) begin
                if (axi_arlen_cntr < axi_arlen) begin
                    axi_arlen_cntr <= axi_arlen_cntr + 1;
                    case (axi_arburst)
                        2'b00: begin // fixed burst
                            axi_araddr <= axi_araddr;        
                        end   
                        2'b01: begin // incremental burst
                            axi_araddr[ADDR_WIDTH - 1:ADDR_LSB] <= axi_araddr[ADDR_WIDTH - 1:ADDR_LSB] + 1; 
                            axi_araddr[ADDR_LSB-1:0] <= {ADDR_LSB{1'b0}};
                        end   
                        2'b10: begin // Wrapping burst
                            if (ar_wrap_en) begin
                                axi_araddr <= (axi_araddr - ar_wrap_size); 
                            end else begin
                                axi_araddr[ADDR_WIDTH - 1:ADDR_LSB] <= axi_araddr[ADDR_WIDTH - 1:ADDR_LSB] + 1; 
                                axi_araddr[ADDR_LSB-1:0] <= {ADDR_LSB{1'b0}};   
                            end
                        end                      
                        default: begin
                            axi_araddr <= axi_araddr[ADDR_WIDTH - 1:ADDR_LSB] + 1;
                        end
                    endcase              
                end
            end          
        end 
    end

    // Read Data & Valid Generation State Machine
    always @(posedge clock_in) begin : read_control_fsm
        if (reset_in == 1'b0) begin
            r_state    <= R_IDLE;
            axi.RVALID <= 1'b0;
            axi.RRESP  <= 2'b0;
            axi.RLAST  <= 1'b0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    axi.RVALID <= 1'b0;
                    axi.RLAST  <= 1'b0;
                    axi.RLAST  <= 1'b0;
                    if (axi.ARVALID && axi.ARREADY) begin
                        // Wait 1 cycle for memory/debug lookup latency
                        r_state <= R_WAIT_LATENCY;
                    end
                end

                R_WAIT_LATENCY: begin
                    // Data is now ready on read_data / debug_read_data
                    axi.RVALID <= 1'b1;
                    axi.RRESP  <= 2'b0;
                    if (axi_arlen_cntr >= axi_arlen) begin
                        axi.RLAST <= 1'b1;
                    end
                    r_state <= R_DATA_PHASE;
                end

                R_DATA_PHASE: begin
                    if (axi.RVALID && axi.RREADY) begin
                        axi.RVALID <= 1'b0;
                        axi.RLAST  <= 1'b0;
                        if (axi_arlen_cntr >= axi_arlen) begin
                            // Burst completed
                            axi_arv_arr_flag <= 1'b0; // Clear flag to allow next AR transaction
                            r_state    <= R_IDLE;
                        end else begin
                            // Multi-beat burst: wait 1 cycle for next address data lookup
                            r_state    <= R_WAIT_LATENCY;
                        end
                    end
                end

                default: r_state <= R_IDLE;
            endcase
        end
    end

    assign write_data = axi.WDATA;
    assign write_address = axi_awaddr;
    assign write_enable = axi.WREADY && axi.WVALID & ~debug_write_en;
    assign axi.RDATA = debug_read_en ? debug_read_data : read_data;
    assign read_address = axi_araddr;

    bit disable_print = 0;
    always_ff @(posedge clock_in) begin 
        if (axi.WREADY && axi.WVALID && ~disable_print) begin
            $display("  reg[%d]: 0x%h", axi_awaddr, axi.WDATA);
            disable_print <= 1;
        end
        if(~axi.WVALID)begin
            disable_print <= 0;
        end
    end

    wire [1:0] debug_selector_r = axi_araddr[ADDR_WIDTH-1:ADDR_WIDTH-2];
    wire [1:0] debug_selector_w = axi_awaddr[ADDR_WIDTH-1:ADDR_WIDTH-2];
    //-----------------------------------------------------------------
    // DEBUG INTERFACE LOGIC
    //-----------------------------------------------------------------
    generate
        if (ENABLE_DEBUG_INTERFACE == "TRUE") begin
            always_ff @(posedge clock_in) begin 
                debug_if.write_mem <= 1'b0;
                debug_if.read_mem <= 1'b0;
                debug_if.start <= 1'b0;
                debug_if.step <= 1'b0;
                if (axi.WREADY && axi.WVALID && debug_write_en) begin
                    if (debug_selector_w == 2'b00) begin // REGISTER WRITE
                        debug_if.mem_addr <= axi_awaddr[ADDR_WIDTH-3: 0];
                        debug_if.write_val <= axi.WDATA;
                        debug_if.write_mem <= 1'b1;
                    end else if (debug_selector_w == 2'b01) begin // CORE_CONTROL
                        if (axi_awaddr[ADDR_WIDTH-3: 0] == 0) begin // START
                            debug_if.start <= 1'b1;
                        end
                        if (axi_awaddr[ADDR_WIDTH-3: 0] == 1) begin // STEP
                            debug_if.step <= 1'b1;
                        end
                    end
                end

                if (axi.ARVALID && axi.ARREADY && debug_read_en) begin
                    if (debug_selector_r == 2'b00) begin // REGISTER READ
                        debug_if.mem_addr <= axi_araddr[ADDR_WIDTH-3: 0];
                        debug_if.read_mem <= 1'b1;                           
                    end
                end
            end    

            always_ff @(posedge clock_in) begin 
                if (~reset_in) begin
                    debug_read_data <= 0;
                end else begin
                    if (debug_selector_r == 2'b00) begin // REGISTER READ
                        debug_read_data <= debug_if.read_val;                     
                    end else if (debug_selector_r == 2'b01) begin // CORE_CONTROL
                        debug_read_data <= debug_if.running;                     
                    end
                end
            end
        end
    endgenerate

endmodule