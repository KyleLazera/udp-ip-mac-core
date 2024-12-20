`ifndef _TX_MAC_TEST
`define _TX_MAC_TEST

class tx_mac_test extends uvm_test;
    `uvm_component_utils(tx_mac_test)        
    
    tx_mac_env          env;
    tx_mac_seq          seq;
    
    function new(string name = "tx_mac_test", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        //Init env
        env = tx_mac_env::type_id::create("tx_mac_env", this);
        
        //Create and randomize sequence
        seq = rx_mac_seq::type_id::create("rx_mac_seq");
        //seq.randomize();
        
    endfunction : build_phase
    
    
    
endclass : tx_mac_test

/*`include "tx_mac_env.sv"
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
    
endclass : tx_mac_test*/

`endif
