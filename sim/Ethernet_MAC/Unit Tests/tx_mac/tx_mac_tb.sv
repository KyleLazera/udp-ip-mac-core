`timescale 1ns / 1ps

`include "tx_mac_test.sv"

module tx_mac_tb;

localparam DATA_WIDTH = 8;
localparam CRC_WIDTH = 32;
localparam TABLE_DEPTH = (2**DATA_WIDTH);
localparam MAX_TESTS = 10;

/* Signals */
logic clk, reset_n;

/* Initialize the interface */
tx_mac_if vif(.clk(clk), .reset_n(reset_n));                        
                      
/* Module Instantiation & connect with the interface*/
tx_mac#(.DATA_WIDTH(DATA_WIDTH)) DUT(.clk(clk), .reset_n(reset_n), .s_tx_axis_tdata(vif.s_tx_axis_tdata), .s_tx_axis_tvalid(vif.s_tx_axis_tvalid),
                                    .s_tx_axis_tlast(vif.s_tx_axis_tlast), .s_tx_axis_tkeep(vif.s_tx_axis_tkeep), .s_tx_axis_tuser(vif.s_tx_axis_tuser), 
                                    .s_tx_axis_trdy(vif.s_tx_axis_trdy),.rgmii_mac_tx_rdy(vif.rgmii_mac_tx_rdy), .rgmii_mac_tx_data(vif.rgmii_mac_tx_data),
                                     .rgmii_mac_tx_dv(vif.rgmii_mac_tx_dv), .rgmii_mac_tx_er(vif.rgmii_mac_tx_er), .mii_select(vif.mii_select));


//Set clk period (8ns for 125 MHz)
always #4 clk = ~clk;

/* Test Declaration */
tx_mac_test test_dut;

//Vars
int num_tests;

initial begin
    //Init Clock Vals
    clk = 0;
   
   /* Randomize total number of test runs */    
    num_tests = $urandom_range(4, MAX_TESTS);
        
    // Iterate over multiple tests - with a reset between each test
    //Multiple tests wil rnaomdize the configiuration for mbit or gbit
    for(int i = 0; i < num_tests; i++) begin
        reset_n = 0;
        #50;
        reset_n = 1;
        #20;
        
        test_dut = new(vif, i);
        test_dut.main();    
    
    end       
            
    #100;
    
    $finish;
      
end

endmodule
