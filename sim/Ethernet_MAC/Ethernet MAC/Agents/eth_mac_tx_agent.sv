`ifndef ETH_MAC_TX_AGENT
`define ETH_MAC_TX_AGENT

`include "uvm_macros.svh"  // Import UVM macros
import uvm_pkg::*;         // Import all UVM classes

`include "eth_mac_item.sv"
`include "eth_mac_tx_seqr.sv"
`include "eth_mac_tx_driver.sv"
`include "eth_mac_tx_monitor.sv"

class eth_mac_tx_agent extends uvm_agent;
    `uvm_component_utils(eth_mac_tx_agent)

    /* Agent components */
    eth_mac_tx_driver   tx_driver;
    eth_mac_tx_monitor  tx_monitor;
    eth_mac_tx_seqr     tx_seqr;

    /* Analysis Export */
    uvm_analysis_port#(eth_mac_item) tx_mon_a_port;
    uvm_analysis_port#(eth_mac_item) tx_drv_a_port;

    function new(string name = "eth_mac_tx_agent", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        /* Instantiate components */
        tx_driver = eth_mac_tx_driver::type_id::create("tx_driver", this);
        tx_monitor = eth_mac_tx_monitor::type_id::create("tx_monitor", this);
        tx_seqr = eth_mac_tx_seqr::type_id::create("tx_seqr", this);
    endfunction : build_phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        tx_driver.seq_item_port.connect(tx_seqr.seq_item_export);
        // Connect the monitor analysis port to this analysis port
        tx_mon_a_port = tx_monitor.tx_mon_scb_port;
        tx_drv_a_port = tx_driver.tx_drv_scb_port;
        
    endfunction : connect_phase

endclass : eth_mac_tx_agent

`endif //ETH_MAC_TX_AGENT