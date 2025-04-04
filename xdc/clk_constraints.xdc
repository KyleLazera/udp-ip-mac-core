#----------------------------------------------------------------------------
# This module is used to generate the clocks used in the design. There are 2 
# primary clocks: 100MHz System Clock and the recieved clock from the RGMII.
# The recieved clock freq can differ from 2.5MHz to 25MHz to 125MHz depending
# on the link speed, but it has been constrained to 125MHz.
# Additionally, the tx clock that is forwaded out via the ODDR is also contrained
# to 125MHz with the source clock being the 90 degree shifted 125MHz signal.
#--------------------------------------------------------------------------------
create_clock -period 8.0 -name rgmii_phy_rxc [get_ports rgmii_phy_rxc]

create_clock -period 10.0 -name i_clk [get_ports i_clk]
create_generated_clock -name mmcm_clk_125 [get_pins clk_mmcm_inst/CLKOUT0] 
create_generated_clock -name mmcm_clk90_125 [get_pins clk_mmcm_inst/CLKOUT1] 
create_generated_clock -name mmcm_clk_200 [get_pins clk_mmcm_inst/CLKOUT2] 
create_generated_clock -name mmcm_clk_feedback [get_pins clk_mmcm_inst/CLKFBOUT]

#Forwarded Clock
create_generated_clock -name rgmii_phy_txc -source [get_pins clk_mmcm_inst/CLKOUT1] -divide_by 1 [get_ports rgmii_phy_txc]
#Virtual clock used by external PHY
create_clock -name virt_rgmii_phy_rxc -period 8





