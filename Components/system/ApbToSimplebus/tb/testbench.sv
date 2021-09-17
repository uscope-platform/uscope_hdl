// Copyright 2021 University of Nottingham Ningbo China
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
`timescale 1ns / 1ps
`include "interfaces.svh"
import axi_vip_pkg::*;
import AXI_VIP_vip1_0_pkg::*;


module apb_to_sb_tb();
    reg clk;
    reg rst;
    APB apb();
    Simplebus spb();
    Simplebus s1();
    Simplebus s2();
    parameter PERIOD =10;	
                
    AXI_VIP_wrapper STIM(
        .apb(apb),
        .clk(clk),
        .rst(rst)
    );

    APB_to_Simplebus DUT(
        .PCLK(clk),
        .PRESETn(rst),
        .apb(apb),
        .spb(spb)
    );
    
    defparam spi.BASE_ADDRESS = 32'h43c00100;
    SPI spi(
        .clock(clk),
        .reset(rst),
        .MISO(0),
        .simple_bus(s2)
    );
    
    defparam xbar.SLAVE_1_LOW = 32'h43c00000;
    defparam xbar.SLAVE_1_HIGH = 32'h43c000fc;
    defparam xbar.SLAVE_2_LOW = 32'h43c00100;
    defparam xbar.SLAVE_2_HIGH = 32'h43c001fc;
    SimplebusInterconnect_M1_S3 xbar(
        .clock(clk),
        .master(spb),
        .slave_1(s1),
        .slave_2(s2)
    );


    // Declare usefull stuff
    AXI_VIP_vip1_0_mst_t      mst_agent;
    axi_transaction rd_trans;
    axi_transaction wr_trans;



    xil_axi_uint                                             mtestID;            // Write ID  
    xil_axi_ulong                                            mtestADDR;          // Write ADDR  
    xil_axi_len_t                                            mtestBurstLength;   // Write Burst Length   
    xil_axi_size_t                                           mtestDataSize;      // Write SIZE  
    xil_axi_burst_t                                          mtestBurstType;     // Write Burst Type  

    /************************************************************************************************
    * A burst can not cross 4KB address boundry for AXI4
    * Maximum data bits = 4*1024*8 =32768
    * Write Data Value for WRITE_BURST transaction
    * Read Data Value for READ_BURST transaction
    ************************************************************************************************/
    bit [32767:0]                                            mtestData;         // Write Data 
    bit[8*4096-1:0]                                          Wdatablock;        // Write data block
    xil_axi_data_beat                                        Wdatabeat[];       // Write data beats
       
    //Clock generationsb_read_strobe
    always begin
       clk<=0;
       #5clk<=1;
       #5;
    end
    
    //Reset signal 
    initial begin
        rst <=1;
        #5 rst<=0;
        #170 rst<=1;
    end

    initial begin
        mtestID = 0;
        #500;
        //Create an agent
        mst_agent = new("slave vip agent",STIM.AXI_VIP_i.vip1.inst.IF);
        // set tag for agents for easy debug
        mst_agent.set_agent_tag("Master VIP");
        // set print out verbosity level.
        mst_agent.set_verbosity(400);
        
        //Start agent
        mst_agent.start_master();
        
        mtestID = $urandom_range(0,(1<<(0)-1)); 
        mtestADDR =  32'h43c00000;
        mtestBurstLength = 0;
        mtestDataSize = xil_axi_size_t'(xil_clog2((32)/8));
        mtestBurstType = XIL_AXI_BURST_TYPE_INCR;
        mtestData = $urandom();
        
        //ADC

        mtestData = $urandom();
        mtestADDR = 32'h43c00000;
        wr_trans = mst_agent.wr_driver.create_transaction("write transaction");
        wr_trans.set_write_cmd(mtestADDR,mtestBurstType,mtestID,mtestBurstLength,mtestDataSize);
        wr_trans.set_data_block(mtestData);
        mst_agent.wr_driver.send(wr_trans);  

        #100;
        mtestData = $urandom();
        mtestADDR = 32'h43c00004;
        wr_trans = mst_agent.wr_driver.create_transaction("write transaction");
        wr_trans.set_write_cmd(mtestADDR,mtestBurstType,mtestID,mtestBurstLength,mtestDataSize);
        wr_trans.set_data_block(mtestData);
        mst_agent.wr_driver.send(wr_trans);  


        #100;
        mtestADDR = 32'h43c00000;
        rd_trans = mst_agent.rd_driver.create_transaction("read transaction");
        rd_trans.set_read_cmd(mtestADDR,mtestBurstType,mtestID,mtestBurstLength,mtestDataSize);
        mst_agent.rd_driver.send(rd_trans);
   
   
        #100;
        mtestADDR = 32'h43c00004;
        rd_trans = mst_agent.rd_driver.create_transaction("read transaction");
        rd_trans.set_read_cmd(mtestADDR,mtestBurstType,mtestID,mtestBurstLength,mtestDataSize);
        mst_agent.rd_driver.send(rd_trans);


        // SPI

        #400; 
        mtestData = $urandom();
        mtestADDR = 32'h43c00100;
        wr_trans = mst_agent.wr_driver.create_transaction("write transaction");
        wr_trans.set_write_cmd(mtestADDR,mtestBurstType,mtestID,mtestBurstLength,mtestDataSize);
        wr_trans.set_data_block(mtestData);
        mst_agent.wr_driver.send(wr_trans);  

        #100;
        mtestData = $urandom();
        mtestADDR = 32'h43c00104;
        wr_trans = mst_agent.wr_driver.create_transaction("write transaction");
        wr_trans.set_write_cmd(mtestADDR,mtestBurstType,mtestID,mtestBurstLength,mtestDataSize);
        wr_trans.set_data_block(mtestData);
        mst_agent.wr_driver.send(wr_trans);  


        #100;
        mtestADDR = 32'h43c00100;
        rd_trans = mst_agent.rd_driver.create_transaction("read transaction");
        rd_trans.set_read_cmd(mtestADDR,mtestBurstType,mtestID,mtestBurstLength,mtestDataSize);
        mst_agent.rd_driver.send(rd_trans);
   
   
        #100;
        mtestADDR = 32'h43c00104;
        rd_trans = mst_agent.rd_driver.create_transaction("read transaction");
        rd_trans.set_read_cmd(mtestADDR,mtestBurstType,mtestID,mtestBurstLength,mtestDataSize);
        mst_agent.rd_driver.send(rd_trans);
   end

endmodule
