`ifndef ETH_MAC_BASE_TEST
`define ETH_MAC_BASE_TEST

//Module includes
`include "eth_mac_env.sv"
`include "eth_mac_wr_agent.sv"
`include "eth_mac_virtual_seqr.sv"
`include "eth_mac_wr_seq.sv"
`include "eth_mac_wr_seqr.sv"
`include "eth_mac_scb.sv"


class eth_mac_base_test extends uvm_test;
    `uvm_component_utils(eth_mac_base_test)

    eth_mac_env eth_mac_env;

    function void new(string name = "eth_mac_base_test", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Build the eth mac env
        eth_mac_env = eth_mac_env::type_id::create("eth_mac_env", this);
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