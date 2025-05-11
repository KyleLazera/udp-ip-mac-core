
# ----------------------------------------------------------------------------------------
# These are used to constrain the double synchronizer FF's used in the asynch FIFO.
# These constraints are more tightly implemented than the normal cdc_signal_sync
# constraints to ensure there is ample time for the grey coded signals to stabilize
# when being passed from one clock domain to another.
# ----------------------------------------------------------------------------------------------




#Set the max delay for the first synchronizers to 1.8ns - rquires datapath_only because this is CDC path
set_max_delay -datapath_only -from [all_clocks] -to [get_pins -filter {REF_PIN_NAME == D} -of [get_cells -hierarchical -filter {NAME =~ *wr_ptr_0_reg*}]] 1.800
set_max_delay -datapath_only -from [all_clocks] -to [get_pins -filter {REF_PIN_NAME == D} -of [get_cells -hierarchical -filter {NAME =~ *rd_ptr_0_reg*}]] 1.800

#Constrain the path in between the 2 FF's
set_max_delay -from [get_pins -filter {REF_PIN_NAME == C} -of [get_cells -hierarchical -filter {NAME =~ *wr_ptr_0_reg*}]] -to [get_pins -filter {REF_PIN_NAME == D} -of [get_cells -hierarchical -filter {NAME =~ *wr_ptr_1_reg*}]] 1.800
set_max_delay -from [get_pins -filter {REF_PIN_NAME == C} -of [get_cells -hierarchical -filter {NAME =~ *rd_ptr_0_reg*}]] -to [get_pins -filter {REF_PIN_NAME == D} -of [get_cells -hierarchical -filter {NAME =~ *rd_ptr_1_reg*}]] 1.800


