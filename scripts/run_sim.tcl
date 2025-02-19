# Set project path - Change to relative
set project_path "../Network Stack/Processorless_Network/Processorless_Network.xpr"
open_project $project_path

# Get project name 
set proj_name [get_projects]

# Get the correct simulation fileset
set sim_set [get_filesets eth_mac_rgmii]

# Set the top-level UVM testbench explicitly
set_property top ethernet_mac_top_tb [get_filesets $sim_set]

# Launch the simulation & open the gui
launch_simulation -simset $sim_set -mode behavioral -scripts_only -gui


