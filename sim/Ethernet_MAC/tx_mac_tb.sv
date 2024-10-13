`timescale 1ns / 1ps

`include "tx_mac_test.sv"

module tx_mac_tb;

localparam DATA_WIDTH = 8;
localparam CRC_WIDTH = 32;
localparam TABLE_DEPTH = (2**DATA_WIDTH);

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

//2 tests, 1 for gigabit and one for megabit ethernet
tx_mac_test test_dut;

initial begin
    //Init Reset and clock vals
    clk = 0;
    reset_n = 0;
    #50;
    reset_n = 1;
    #20;
    
    test_dut = new(vif);
    test_dut.main();
    
    
    #100;
    
    $finish;
      
end

endmodule
