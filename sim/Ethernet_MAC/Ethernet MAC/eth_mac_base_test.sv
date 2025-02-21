`ifndef ETH_MAC_BASE_TEST
`define ETH_MAC_BASE_TEST

`include "uvm_macros.svh"  // Import UVM macros
import uvm_pkg::*;         // Import all UVM classes

//Module includes
`include "eth_mac_env.sv"
`include "eth_mac_tx_agent.sv"
`include "eth_mac_virtual_seqr.sv"
`include "eth_mac_tx_seq.sv"
`include "eth_mac_tx_seqr.sv"
`include "eth_mac_scb.sv"
`include "eth_mac_cfg.sv"


class eth_mac_base_test extends uvm_test;
    `uvm_component_utils(eth_mac_base_test)

    eth_mac_env env;
    eth_mac_cfg cfg;

    function new(string name = "eth_mac_base_test", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);     

        //Build the eth mac env
        env = eth_mac_env::type_id::create("eth_mac_env", this);  

        // Instantiate cfg only in the base test
        cfg = eth_mac_cfg::type_id::create("cfg"); 

        // Store cfg in the config database so environment can access it
        uvm_config_db#(eth_mac_cfg)::set(this, "eth_mac_env", "cfg", cfg);                
    endfunction : build_phase

    virtual function void report_phase(uvm_phase phase);
        //Instance of uvm report server
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

endclass : eth_mac_base_test

`endif //ETH_MAC_BASE_TEST