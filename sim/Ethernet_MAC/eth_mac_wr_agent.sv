`ifndef ETH_MAC_WR_AGENT
`define ETH_MAC_WR_AGENT

`include "uvm_macros.svh"  // Import UVM macros
import uvm_pkg::*;         // Import all UVM classes

`include "eth_mac_wr_item.sv"
`include "eth_mac_wr_seqr.sv"
`include "eth_mac_wr_driver.sv"
`include "eth_mac_wr_monitor.sv"

class eth_mac_wr_agent extends uvm_agent;
    `uvm_component_utils(eth_mac_wr_agent)

    /* Agent components */
    eth_mac_wr_driver   wr_driver;
    eth_mac_wr_mon      wr_monitor;
    eth_mac_wr_seqr     wr_seqr;

    /* Analaysis Export */
    uvm_analysis_port#(eth_mac_wr_item) a_port;

    function void new(string name = "eth_mac_wr_agent", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        /* Instantiate components */
        wr_driver = eth_mac_wr_driver::type_id::create("wr_driver", this);
        wr_monitor = eth_mac_wr_mon::type_id::create("wr_monitor", this);
        wr_seqr = eth_mac_wr_seqr::type_id::create("wr_seqr", this);
    endfunction : build_phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Connect the monitor analysis port to this analysis port
        a_port = wr_monitor.a_port;
        //TODO: Connect driver analysis port to reference model here
        
    endfunction : connect_phase

endclass : eth_mac_wr_agent

`endif //ETH_MAC_WR_AGENT