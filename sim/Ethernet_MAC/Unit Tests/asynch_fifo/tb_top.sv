`timescale 1ns / 1ps

`include "uvm_macros.svh"  // Import UVM macros
import uvm_pkg::*;         // Import all UVM classes

`include "fifo_sva.sv"
`include "fifo_case0.sv"
`include "fifo_case1.sv"
`include "fifo_case2.sv"

module tb_top;
    
    /* Signals */
    reg clk_wr, clk_rd;
    reg reset_n;
    
    /* Virtual Interfaces */
    wr_if wr_if(clk_wr, reset_n);
    rd_if rd_if(clk_rd, reset_n);
    
    /* DUT Instantiation */
    fifo#(.DATA_WIDTH(8), .FIFO_DEPTH(256)) fifo_dut (.clk_wr(clk_wr), .clk_rd(clk_rd), .reset_n(reset_n), .data_in(wr_if.data_in),
                                                    .write_en(wr_if.wr_en), .data_out(rd_if.data_out), .read_en(rd_if.rd_en), 
                                                    .empty(rd_if.empty), .full(wr_if.full), .almost_full(wr_if.almost_full), 
                                                    .almost_empty(rd_if.almost_empty));

    /* Bind SVA file */    
    bind fifo fifo_sva assertions_inst(
        .clk_wr(clk_wr), .clk_rd(clk_rd), 
        .reset_n(reset_n), 
        .data_in(data_in),
        .write_en(write_en), 
        .data_out(data_out), 
        .read_en(read_en), 
        .empty(empty), 
        .full(full),
        .almost_full(almost_full), 
        .almost_empty(almost_empty)  
    );
                                                    
   /* Write Clock Initialization */
   initial begin
        clk_wr = 1'b0;
        forever #5 clk_wr =~ clk_wr; //100MHz
   end

    /* Read Clock Init */
    initial begin
        clk_rd = 1'b0;
        forever #4 clk_rd =~ clk_rd; //125MHz
    end
    
    /* Reset the module */
    initial begin
        reset_n = 1'b0;
        #50;
        reset_n = 1'b1;
    end
    
    /* Initialize virtual interfaces with uvm_config & run default test*/
    initial begin
        //reset_n = 1'b1;
        uvm_config_db#(virtual wr_if)::set(null, "uvm_test_top.fifo_env.wr_fifo.drv", "wr_if", wr_if);
        uvm_config_db#(virtual wr_if)::set(null, "uvm_test_top.fifo_env.wr_fifo.mon", "wr_if", wr_if);
        uvm_config_db#(virtual rd_if)::set(null, "uvm_test_top.fifo_env.rd_fifo.drv", "rd_if", rd_if);
        uvm_config_db#(virtual rd_if)::set(null, "uvm_test_top.fifo_env.rd_fifo.mon", "rd_if", rd_if);
                
        run_test("fifo_case0");
        //run_test("fifo_case1");
        //run_test("fifo_case2");
    end
   

endmodule
