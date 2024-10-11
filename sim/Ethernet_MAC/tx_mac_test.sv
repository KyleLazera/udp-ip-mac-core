`ifndef _TX_MAC_TEST
`define _TX_MAC_TEST

`include "tx_mac_env.sv"

class tx_mac_test;
    //instantiate environemnt
    tx_mac_env  env;
    string TAG = "Test";
    
    //Constructor
    function new(virtual tx_mac_if _vif);
        env = new(_vif);
    endfunction : new
    
    task main();
        $display("[%s] Stating...", TAG);
        
        fork
            env.main();
        join_any
        
        #100;
    endtask : main    
    
endclass : tx_mac_test

`endif
