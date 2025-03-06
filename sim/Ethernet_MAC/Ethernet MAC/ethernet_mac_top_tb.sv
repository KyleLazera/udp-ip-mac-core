`timescale 1ns / 1ps

`include "uvm_macros.svh"  // Import UVM macros
import uvm_pkg::*;         // Import all UVM classes

`include "tc_half_duplex_tx_random.sv"
`include "tc_half_duplex_rx_random.sv"
`include "tc_full_duplex_random.sv"
`include "eth_mac_wr_if.sv"
`include "eth_mac_rd_if.sv"


module ethernet_mac_top_tb;

logic clk_125;
logic clk90_125;
logic clk_100;
logic reset_n;

//Instantiate virtual interfaces
eth_mac_wr_if eth_wr_if (clk_100, reset_n); //write vif
eth_mac_rd_if eth_rd_if (clk_100, reset_n); //read interface

//DUT
ethernet_mac_fifo#(
    .FIFO_DATA_WIDTH(9),
    .FIFO_DEPTH(4096),
    .AXI_DATA_WIDTH(8),
    .RGMII_DATA_WIDTH(4)
) eth_mac_fifo_0 (
    .i_clk(clk_100),
    .clk_125(clk_125),
    .clk90_125(clk90_125),
    .i_reset_n(reset_n),
    .rgmii_phy_rxc(eth_rd_if.rgmii_phy_rxc), 
    .rgmii_phy_rxd(eth_rd_if.rgmii_phy_rxd), 
    .rgmii_phy_rxctl(eth_rd_if.rgmii_phy_rxctl),
    .rgmii_phy_txc(eth_wr_if.rgmii_phy_txc), 
    .rgmii_phy_txd(eth_wr_if.rgmii_phy_txd), 
    .rgmii_phy_txctl(eth_wr_if.rgmii_phy_txctl),
    /* Tx Data */
    .m_tx_axis_tdata(eth_wr_if.m_tx_axis_tdata),
    .m_tx_axis_tvalid(eth_wr_if.m_tx_axis_tvalid),
    .m_tx_axis_tlast(eth_wr_if.m_tx_axis_tlast),
    .s_tx_axis_trdy(eth_wr_if.s_tx_axis_trdy),
    /* RX Signals */
    .m_rx_axis_tdata(eth_rd_if.m_rx_axis_tdata),
    .m_rx_axis_tvalid(eth_rd_if.m_rx_axis_tvalid),
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

    run_test("tc_half_duplex_tx_random");
end


endmodule
