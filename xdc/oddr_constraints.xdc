#-------------------------------------------------------------------
# These constraints target the ODDR's used to transmit data from the ethernet
# MAC to the PHY.
#-------------------------------------------------------------------------

set tx_oddr_cells [get_cells -hierarchical -filter {NAME =~ "*data_oddr*genblk1[*].ODDR_inst"}]

# RGMII PHY has min setup time of 1.2ns
set_output_delay -clock rgmii_phy_txc -max 1.2 [get_ports {rgmii_phy_txd[*]}]
set_output_delay -clock rgmii_phy_txc -max 1.2 [get_ports {rgmii_phy_txd[*]}] -clock_fall -add_delay

set_output_delay -clock rgmii_phy_txc -max 1.2 [get_ports rgmii_phy_txctl]
set_output_delay -clock rgmii_phy_txc -max 1.2 [get_ports rgmii_phy_txctl] -clock_fall -add_delay

#RGMII PHY has minimum hold time of 1.0 ns
set_output_delay -clock rgmii_phy_txc -min 1.0 [get_ports {rgmii_phy_txd[*]}]
set_output_delay -clock rgmii_phy_txc -min 1.0 [get_ports {rgmii_phy_txd[*]}] -clock_fall -add_delay

set_output_delay -clock rgmii_phy_txc -min 1.0 [get_ports rgmii_phy_txctl]
set_output_delay -clock rgmii_phy_txc -min 1.0 [get_ports rgmii_phy_txctl] -clock_fall -add_delay