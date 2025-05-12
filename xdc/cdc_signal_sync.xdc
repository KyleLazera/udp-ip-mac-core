# ---------------------------------------------------------------------------
# This file is used to target the double synchronizer FF's that are used for
# CDC throughout the design.
# Note: These do NOT target the double synchronizers used in the aynch FIFO,
# as those require tighter constraits due to passing Grey code across domains
# ---------------------------------------------------------------------------



set_max_delay -datapath_only -from [all_clocks] -to [get_pins -filter {REF_PIN_NAME == D} -of [get_cells -hierarchical -filter {NAME =~ *cdc_signal_sync_reg_reg[0]*}]] 20.000

set_max_delay -from [get_pins -filter {REF_PIN_NAME == C} -of [get_cells -hierarchical -filter {NAME =~ *cdc_signal_sync_reg_reg[0]*}]] -to [get_pins -filter {REF_PIN_NAME == D} -of [get_cells -hierarchical -filter {NAME =~ *cdc_signal_sync_reg_reg[1]*}]] 1.800

set_max_delay -from [all_inputs] -to [get_pins -filter {REF_PIN_NAME == D} -of [get_cells -hierarchical -filter {NAME =~ *cdc_signal_sync_reg_reg[0]*}]] 10.000


