#Generate the 100MHz and 125MHz clocks that will feed into the ethernet MAC
create_clock -period 10.0 -name i_clk [get_ports i_clk]
create_clock -period 8.0 -name clk_125 [get_ports clk_125]
create_clock -period 8.0 -name clk90_125 -waveform {2.000 6.000} [get_ports clk90_125]
create_clock -period 8.0 -name rgmii_phy_rxc [get_ports rgmii_phy_rxc]
