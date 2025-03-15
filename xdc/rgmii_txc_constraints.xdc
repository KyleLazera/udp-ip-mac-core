#---------------------------------------------------------------------------
# The RGMII module is responsible for forwarding teh txc clock that is 
# used for data recovery by the PHY. This clock is output using an ODDR which
# is fed by 2 registers (txc_1 and txc_2). These launching registers are driven
# by the 125MHz clock. However, the RGMII standard specifies that the tx data and 
# tx clock should not be aligned (introduce a 90 degree phase shift). Therefore, the 
# ODDR (only for teh txc) is driven by a 125MHz clock with a 90 degree phase shift.
# To avoid timing violations a multicycle path must be specified to ensure that 
# the latching clock edge occurs 2 clock cycles after the launch edge.
#
# https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Multicycle-Paths-and-Clock-Phase-Shift
#-----------------------------------------------------------------------------------

set_multicycle_path 3 -setup -from [get_clocks mmcm_clk_125] -to [get_clocks mmcm_clk90_125]
set_multicycle_path 2 -hold -from [get_clocks mmcm_clk_125] -to [get_clocks mmcm_clk90_125]

#set_max_delay -from [get_pins -filter {REF_PIN_NAME == C} -of [get_cells -hierarchical -filter {NAME =~ *rgmii_txc_2_reg*}]] -to [get_pins -filter {REF_PIN_NAME == D2} -of [get_cells -hierarchical -filter {NAME =~ *clk_oddr*genblk1[0].ODDR_inst*}]] 2.0
#set_max_delay -from [get_pins -filter {REF_PIN_NAME == C} -of [get_cells -hierarchical -filter {NAME =~ *rgmii_txc_1_reg*}]] -to [get_pins -filter {REF_PIN_NAME == D1} -of [get_cells -hierarchical -filter {NAME =~ *clk_oddr*genblk1[0].ODDR_inst*}]] 2.0
