#-----------------------------------------------------------------------------
# These constraints target the IDDR's used to recieve data from the ethernet
# PHY.
#-----------------------------------------------------------------------------


# RGMII PHY Had a max clock to data skew of 0.5 & has min clock to data skew of -0.5
set_input_delay -clock virt_rgmii_phy_rxc -max 0.500 [get_ports {rgmii_phy_rxd[*]}]
set_input_delay -clock virt_rgmii_phy_rxc -clock_fall -max -add_delay 0.500 [get_ports {rgmii_phy_rxd[*]}]
set_input_delay -clock virt_rgmii_phy_rxc -min -0.500 [get_ports {rgmii_phy_rxd[*]}]
set_input_delay -clock virt_rgmii_phy_rxc -clock_fall -min -add_delay -0.500 [get_ports {rgmii_phy_rxd[*]}]

set_input_delay -clock virt_rgmii_phy_rxc -max 0.500 [get_ports rgmii_phy_rxctl]
set_input_delay -clock virt_rgmii_phy_rxc -clock_fall -max -add_delay 0.500 [get_ports rgmii_phy_rxctl]
set_input_delay -clock virt_rgmii_phy_rxc -min -0.500 [get_ports rgmii_phy_rxctl]
set_input_delay -clock virt_rgmii_phy_rxc -clock_fall -min -add_delay -0.500 [get_ports rgmii_phy_rxctl]


#-------------------------------------------------------------------------------------------------------
# When working with Double Data Rate special consideration has to be given to the relationship
# between the launch and capture edge. Double Data Rate registers are seen as two registers:
# 1 driven by the positive edge and another driven by a negative edge. Because the PHY drives data
# at DDR and teh MAC recieves data via a IDDR, there are essentially 4 paths the timing tool will see:
# 1) Rising launching edge to rising latching edge
# 2) Rising launching edge to falling latching edge
# 3) Falling launching edge to falling latching edge
# 4) Falling launching edge to Rising latching edge
# Because a 2ns delay is implemented via an IDELAY2 in the MAC, the data that is driven by the rising
# should be sampled by the next falling edge and vice versa. Therefore, we set the 1st and 3rd
# paths (above) as false paths - tell the tool to ignore these.
#
# https://zhuanlan.zhihu.com/p/31585375
#---------------------------------------------------------------------------------------------------
set_false_path -setup -rise_from [get_clocks virt_rgmii_phy_rxc] -rise_to [get_clocks rgmii_phy_rxc]
set_false_path -setup -fall_from [get_clocks virt_rgmii_phy_rxc] -fall_to [get_clocks rgmii_phy_rxc]

set_false_path -hold -rise_from [get_clocks virt_rgmii_phy_rxc] -rise_to [get_clocks rgmii_phy_rxc]
set_false_path -hold -fall_from [get_clocks virt_rgmii_phy_rxc] -fall_to [get_clocks rgmii_phy_rxc]



