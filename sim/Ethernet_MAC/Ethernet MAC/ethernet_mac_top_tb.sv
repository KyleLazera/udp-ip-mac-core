`timescale 1ns / 1ps

`include "uvm_macros.svh"  // Import UVM macros
import uvm_pkg::*;         // Import all UVM classes

`include "tc_eth_mac_wr_only.sv"
`include "tc_eth_mac_rd_wr.sv"
`include "eth_mac_wr_if.sv"
`include "eth_mac_rd_if.sv"


module ethernet_mac_top_tb;

logic clk_125;
logic clk90_125;
logic clk_100;
logic reset_n;

//Instantiate virtual interfaces
eth_mac_wr_if eth_wr_if (clk_125, clk90_125, reset_n); //write vif
eth_mac_rd_if eth_rd_if (clk_125, clk90_125, clk_100, reset_n); //read interface

//DUT 
ethernet_mac#(.FIFO_DATA_WIDTH(8), .RGMII_DATA_WIDTH(4)) 
    eth_mac_1(.clk_125(clk_125), 
              .clk90_125(clk90_125), 
              .reset_n(reset_n),
              .rgmii_phy_rxc(eth_rd_if.rgmii_phy_rxc), 
              .rgmii_phy_rxd(eth_rd_if.rgmii_phy_rxd), 
              .rgmii_phy_rxctl(eth_rd_if.rgmii_phy_rxctl),
              .rgmii_phy_txc(eth_wr_if.rgmii_phy_txc), 
              .rgmii_phy_txd(eth_wr_if.rgmii_phy_txd), 
              .rgmii_phy_txctl(eth_wr_if.rgmii_phy_txctl),
              .s_tx_axis_tdata(eth_wr_if.s_tx_axis_tdata), 
              .s_tx_axis_tvalid(eth_wr_if.s_tx_axis_tvalid), 
              .s_tx_axis_tlast(eth_wr_if.s_tx_axis_tlast), 
              .s_tx_axis_trdy(eth_wr_if.s_tx_axis_trdy), 
              .m_rx_axis_tdata(eth_rd_if.m_rx_axis_tdata), 
              .m_rx_axis_tvalid(eth_rd_if.m_rx_axis_tvalid), 
              .m_rx_axis_tuser(eth_rd_if.m_rx_axis_tuser), 
              .m_rx_axis_tlast(eth_rd_if.m_rx_axis_tlast), 
              .s_rx_axis_trdy(eth_rd_if.s_rx_axis_trdy)
);

//125 MHz clock input
always #4 clk_125 = ~clk_125;

//100MHz clock 
always #5 clk_100 = ~clk_100;

//Phase shift for clk90_125 by 90 degrees
initial begin
    clk_125 = 1'b0;
    clk_100 = 1'b0;
    #2 clk90_125 = 1'b0;
    forever #4 clk90_125 = ~clk90_125;
end

//Reset Block 
initial begin
   reset_n = 1'b0;
   #1000;
   reset_n = 1'b1;
end

initial begin
    uvm_config_db#(virtual eth_mac_wr_if)::set(null, "uvm_test_top.eth_mac_env.tx_agent.tx_driver", "eth_mac_wr_if", eth_wr_if);
    uvm_config_db#(virtual eth_mac_wr_if)::set(null, "uvm_test_top.eth_mac_env.tx_agent.tx_monitor", "eth_mac_wr_if", eth_wr_if);
    uvm_config_db#(virtual eth_mac_rd_if)::set(null, "uvm_test_top.eth_mac_env.rx_agent.rx_driver", "eth_mac_rd_if", eth_rd_if);
    uvm_config_db#(virtual eth_mac_rd_if)::set(null, "uvm_test_top.eth_mac_env.rx_agent.rx_monitor", "eth_mac_rd_if", eth_rd_if);    

    run_test("tc_eth_mac_rd_only");
    //run_test("tc_eth_mac_wr_only");
    //run_test("tc_eth_mac_rd_wr");
end


endmodule
