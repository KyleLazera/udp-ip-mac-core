#-------------------------------------------------------------------
# These constraints target the ODDR's used to transmit data from the ethernet
# MAC to the PHY.
#-------------------------------------------------------------------------


# RGMII PHY has min setup time of 1.2ns
set_output_delay -clock rgmii_phy_txc -max 1.200 [get_ports {rgmii_phy_txd[*]}]
set_output_delay -clock rgmii_phy_txc -clock_fall -max -add_delay 1.200 [get_ports {rgmii_phy_txd[*]}]

set_output_delay -clock rgmii_phy_txc -max 1.200 [get_ports rgmii_phy_txctl]
set_output_delay -clock rgmii_phy_txc -clock_fall -max -add_delay 1.200 [get_ports rgmii_phy_txctl]

#RGMII PHY has minimum hold time of 1.0 ns
set_output_delay -clock rgmii_phy_txc -min 1.000 [get_ports {rgmii_phy_txd[*]}]
set_output_delay -clock rgmii_phy_txc -clock_fall -min -add_delay 1.000 [get_ports {rgmii_phy_txd[*]}]

set_output_delay -clock rgmii_phy_txc -min 1.000 [get_ports rgmii_phy_txctl]
set_output_delay -clock rgmii_phy_txc -clock_fall -min -add_delay 1.000 [get_ports rgmii_phy_txctl]

