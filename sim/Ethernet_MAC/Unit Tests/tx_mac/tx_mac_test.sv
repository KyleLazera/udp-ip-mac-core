`ifndef _TX_MAC_TEST
`define _TX_MAC_TEST

`include "tx_mac_env.sv"
`include "tx_mac_seq.sv"

/* This class is the base testcase that all other testcases inherit from */

class tx_mac_test extends uvm_test;
    `uvm_component_utils(tx_mac_test)        
    
    tx_mac_env          env;
    
    function new(string name = "tx_mac_test", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        //Init env
        env = tx_mac_env::type_id::create("tx_mac_env", this);                
    endfunction : build_phase
    
    virtual function void report_phase(uvm_phase phase);
        uvm_report_server   server;
        //Variable to track number of errors
        int err_num;
        super.report_phase(phase);
        
        server = get_report_server();
        err_num = server.get_severity_count(UVM_ERROR);
        
        if (err_num != 0) 
           $display("TEST CASE FAILED");
        else 
           $display("TEST CASE PASSED");                                
                
    endfunction : report_phase
    
endclass : tx_mac_test

`endif
