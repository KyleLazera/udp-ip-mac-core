# Simple regression script to run through all teh UVM testcases with different seed values. This can be invoked by calling
# vivado -mode batch -source scripts/run_regression.tcl

# Set project path - Change to relative
set project_path "../Network Stack/Processorless_Network/Processorless_Network.xpr"
set tc_path      "../sim/Ethernet_MAC/Ethernet MAC"
open_project $project_path

#Search the Ethernet MAC directory for all files with prefix tc_*
set tc_files [glob "$tc_path/tc_*"]

set testcases []

#Iterate through each testcase and append it to the testcases list above
foreach tc $tc_files {
    set tc_name [file tail $tc]

    #remove .sv extension
    set testcase [file rootname $tc_name]
    lappend testcases $testcase
}

puts $testcases

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

    # Generate a random seed for each test
    set random_seed [expr {int(rand() * 10000)}] 

    #Pass the testcase to run as an argument to UVM & pass a randomized seed
    set_property -name {xsim.simulate.xsim.more_options} -value "-testplusarg UVM_TESTNAME=$test -sv_seed $random_seed" -objects [get_filesets eth_mac_rgmii]

    # Remove old log files
    file delete -force xsim.log simulate.log    

    # Run the simulation in batch mode 
    launch_simulation -simset $sim_set 

    run -all
}

close_project
exit



