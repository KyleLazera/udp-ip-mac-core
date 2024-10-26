`ifndef _TX_MAC_TEST
`define _TX_MAC_TEST

`include "tx_mac_env.sv"
`include "tx_mac_cfg.sv"

class tx_mac_test;
    //instantiate environemnt
    tx_mac_env  env;
    tx_mac_cfg  cfg;
    
    int test_num;
    string TAG = "Test";
    
    //Constructor
    function new(virtual tx_mac_if _vif, int _test);
        cfg = new;  
        env = new(_vif, cfg);       
        test_num = _test;   
    endfunction : new
    
    task main();
        $display("[%s] Test %0d Stating...", TAG, test_num);
        
        fork
            env.main();
        join_any
        
        #100;
        
        display_final();
    endtask : main    
    
    function display_final();
        env.scb.display_score();
    endfunction : display_final
    
endclass : tx_mac_test

`endif
