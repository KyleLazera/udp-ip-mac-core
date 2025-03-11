
proc find_testecase{folder_path}{

    #Search the Ethernet MAC directory for all files with prefix tc_*
    set tc_files [glob "$folder_path/tc_*"]

    set testcases []

    #Iterate through each testcase and append it to the testcases list above
    foreach tc $tc_files {
        set tc_name [file tail $tc]

        #remove .sv extension
        set testcase [file rootname $tc_name]
        lappend testcases $testcase
    }

    return $testcases
}