`timescale 1ns / 1ps

`include "uvm_macros.svh"  // Import UVM macros
import uvm_pkg::*;         // Import all UVM classes

`include "tx_mac_test.sv"
`include "tx_mac_sva.sv"
`include "tx_mac_100mbps_test.sv"

module tx_mac_tb;

localparam DATA_WIDTH = 8;

/* Signals */
logic clk, reset_n;

/* Initialize the interface */
tx_mac_if tx_if(.clk(clk), .reset_n(reset_n));                        
                      
/* Module Instantiation & connect with the interface*/
tx_mac#(.DATA_WIDTH(DATA_WIDTH)) DUT(.clk(clk), .reset_n(reset_n), .s_tx_axis_tdata(tx_if.s_tx_axis_tdata), .s_tx_axis_tvalid(tx_if.s_tx_axis_tvalid),
                                    .s_tx_axis_tlast(tx_if.s_tx_axis_tlast), .s_tx_axis_tkeep(tx_if.s_tx_axis_tkeep), .s_tx_axis_tuser(tx_if.s_tx_axis_tuser), 
                                    .s_tx_axis_trdy(tx_if.s_tx_axis_trdy),.rgmii_mac_tx_rdy(tx_if.rgmii_mac_tx_rdy), .rgmii_mac_tx_data(tx_if.rgmii_mac_tx_data),
                                     .rgmii_mac_tx_dv(tx_if.rgmii_mac_tx_dv), .rgmii_mac_tx_er(tx_if.rgmii_mac_tx_er), .mii_select(tx_if.mii_select));


//Bind systemveriog assertion file
bind tx_mac tx_mac_sva sva_inst(.clk(clk), .reset_n(reset_n), 
.s_tx_axis_tdata(s_tx_axis_tdata), .s_tx_axis_tvalid(s_tx_axis_tvalid),
.s_tx_axis_tlast(s_tx_axis_tlast), .s_tx_axis_tkeep(s_tx_axis_tkeep), 
.s_tx_axis_tuser(s_tx_axis_tuser), .s_tx_axis_trdy(s_tx_axis_trdy),
.rgmii_mac_tx_rdy(rgmii_mac_tx_rdy), .rgmii_mac_tx_data(rgmii_mac_tx_data),
.rgmii_mac_tx_dv(rgmii_mac_tx_dv), .rgmii_mac_tx_er(rgmii_mac_tx_er), .mii_select(mii_select)    
);

//Set clk period (8ns for 125 MHz)
always #4 clk = ~clk;

/* Reset the module */
initial begin
    reset_n = 1'b0;
    #50;
    reset_n = 1'b1;
end

/* set the virtual interface & begin test */
initial begin
    clk = 1'b0;
    
    uvm_config_db#(virtual tx_mac_if)::set(null, "uvm_test_top.tx_mac_env.tx_mac_agent.tx_mac_driver", "tx_if", tx_if);
    uvm_config_db#(virtual tx_mac_if)::set(null, "uvm_test_top.tx_mac_env.tx_mac_agent.tx_mac_monitor", "tx_if", tx_if);
        
    //run_test("tx_mac_1gbps_test");
    run_test("tx_mac_100mbps_test");
end

endmodule
