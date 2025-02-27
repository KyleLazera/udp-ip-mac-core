# Set project path - Change to relative
set project_path "../Network Stack/Processorless_Network/Processorless_Network.xpr"
open_project $project_path

#Define teh testcases to run
set testcases {"tc_full_duplex_random" "tc_half_duplex_tx_random" "tc_half_duplex_rx_random"}

# Get project name 
set proj_name [get_projects]

# Get the correct simulation fileset
set sim_set [get_filesets eth_mac_rgmii]

# Set the top-level UVM testbench explicitly
set_property top ethernet_mac_top_tb [get_filesets $sim_set]

#Run each testcase
foreach test $testcases {
    puts "Running UVM Test: $test"

    # Reset simulation to ensure a fresh start
    reset_simulation    

    set_property -name {xsim.simulate.xsim.more_options} -value "-testplusarg UVM_TESTNAME=$test" -objects [get_filesets eth_mac_rgmii]

    # Remove old log files
    file delete -force xsim.log simulate.log    

    # Run the simulation in batch mode 
    launch_simulation -simset $sim_set 

    run -all
}

close_project
exit



