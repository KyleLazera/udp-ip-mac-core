# Set project path - Change to relative
set project_path "../Network Stack/Processorless_Network/Processorless_Network.xpr"
open_project $project_path

#Define teh testcases to run
set testcases {"tc_eth_mac_rd_only" "tc_eth_mac_wr_only"}

# Get project name 
set proj_name [get_projects]

# Get the correct simulation fileset
set sim_set [get_filesets eth_mac_rgmii]

# Set the top-level UVM testbench explicitly
set_property top ethernet_mac_top_tb [get_filesets $sim_set]

#Run each testcase
foreach test $testcases {
    puts "Running UVM Test: $test"

    set_property -name {XSIM.MORE_OPTIONS} -value {UVM_TESTNAME=$test} -objects $sim_set

    # Remove old log files
    file delete -force xsim.log simulate.log    

    # Run the simulation in batch mode 
    launch_simulation -simset $sim_set 
}

close_project
exit



