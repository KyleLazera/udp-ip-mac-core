`timescale 1ns / 1ps

`include "uvm_macros.svh"  // Import UVM macros
import uvm_pkg::*;         // Import all UVM classes

`include "tc_eth_mac_wr_only.sv"
`include "eth_mac_wr_if.sv"

module ethernet_mac_top_tb;

logic clk_125;
logic clk90_125;
logic reset_n;

//Instantiate virtual interfaces
eth_mac_wr_if eth_wr_if (clk_125, clk90_125, reset_n); //write vif

//DUT 
ethernet_mac#(.FIFO_DATA_WIDTH(8), .RGMII_DATA_WIDTH(4)) 
    eth_mac_1(.clk_125(clk_125), 
              .clk90_125(clk90_125), 
              .reset_n(reset_n),
              .rgmii_phy_rxc(), 
              .rgmii_phy_rxd(), 
              .rgmii_phy_rxctl(),
              .rgmii_phy_txc(eth_wr_if.rgmii_phy_txc), 
              .rgmii_phy_txd(eth_wr_if.rgmii_phy_txd), 
              .rgmii_phy_txctl(eth_wr_if.rgmii_phy_txctl),
              .s_tx_axis_tdata(eth_wr_if.s_tx_axis_tdata), 
              .s_tx_axis_tvalid(eth_wr_if.s_tx_axis_tvalid), 
              .s_tx_axis_tlast(eth_wr_if.s_tx_axis_tlast), 
              .s_tx_axis_trdy(eth_wr_if.s_tx_axis_trdy), 
              .m_rx_axis_tdata(), 
              .m_rx_axis_tvalid(), 
              .m_rx_axis_tuser(), 
              .m_rx_axis_tlast(), 
              .s_rx_axis_trdy()
);

//125 MHz clock input
always #4 clk_125 = ~clk_125;

//Phase shift for clk90_125 by 90 degrees
initial begin
    clk_125 = 1'b0;
    #2 clk90_125 = 1'b0;
    forever #4 clk90_125 = ~clk90_125;
end

//Reset Block 
initial begin
   repeat(10) reset_n = 1'b0; 
   reset_n = 1'b1;
end

initial begin
    uvm_config_db#(virtual eth_mac_wr_if)::set(null, "ethernet_mac_top_tb.eth_mac_env.wr_agent.wr_driver", "wr_if", eth_wr_if);
    uvm_config_db#(virtual eth_mac_wr_if)::set(null, "ethernet_mac_top_tb.eth_mac_env.wr_agent.wr_monitor", "wr_if", eth_wr_if);

    run_test("tc_wr_only");
end


endmodule
