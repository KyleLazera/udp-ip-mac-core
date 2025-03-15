
# ----------------------------------------------------------------------------------------
# These are used to constrain the double synchronizer FF's used in the asynch FIFO.
# These constraints are more tightly implemented than the normal cdc_signal_sync 
# constraints to ensure there is ample time for the grey coded signals to stabalize 
# when being passed from one clock domain to another.
# ----------------------------------------------------------------------------------------------

set tLowPd 1.8

set cdc_w2r_cell_0 [get_cells -hierarchical -filter {NAME =~ *wr_ptr_0_reg*}]
set cdc_r2w_cell_0 [get_cells -hierarchical -filter {NAME =~ *rd_ptr_0_reg*}]

#Set the max delay for the first synchronizers to 1.8ns 
set_max_delay -datapath_only -from [all_clocks] -to [get_pins -filter {REF_PIN_NAME == D} -of $cdc_w2r_cell_0] $tLowPd
set_max_delay -datapath_only -from [all_clocks] -to [get_pins -filter {REF_PIN_NAME == D} -of $cdc_r2w_cell_0] $tLowPd

set_max_delay -from [get_pins -filter {REF_PIN_NAME == C} -of $cdc_w2r_cell_0] -to [get_pins -filter {REF_PIN_NAME == D} -of [get_cells -hierarchical -filter {NAME =~ *wr_ptr_1_reg*}]] $tLowPd
set_max_delay -from [get_pins -filter {REF_PIN_NAME == C} -of $cdc_r2w_cell_0] -to [get_pins -filter {REF_PIN_NAME == D} -of [get_cells -hierarchical -filter {NAME =~ *rd_ptr_1_reg*}]] $tLowPd