`ifndef _RX_MAC_AGENT
`define _RX_MAC_AGENT

`include "rx_mac_rgmii_item.sv"
`include "rx_mac_driver.sv"
`include "rx_mac_monitor.sv"

class rx_mac_agent extends uvm_agent;
    /* Utility Macros */
    `uvm_component_utils(rx_mac_agent)
    
    /* Component handles */    
    rx_mac_driver                       driver;
    rx_mac_monitor                      monitor;
    uvm_sequencer#(rx_mac_rgmii_item)   seq;    
    
    /* Constructor */
    function new(string name = "Agent", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    /* Build phase - Initialize each component */
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seq = uvm_sequencer#(rx_mac_rgmii_item)::type_id::create("seq", this);
        driver = rx_mac_driver::type_id::create("driver", this);
        monitor = rx_mac_monitor::type_id::create("monitor", this);
    endfunction : build_phase
    
    /* Connect Phase - Connect various components via TLM ports */
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        //Connect driver to sequencer
        driver.seq_item_port.connect(seq.seq_item_export);
    endfunction : connect_phase 
    
endclass : rx_mac_agent

`endif //_RX_MAC_AGENT