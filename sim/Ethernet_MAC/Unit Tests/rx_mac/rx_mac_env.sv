`ifndef _RX_MAC_ENV
`define _RX_MAC_ENV

`include "rx_mac_rgmii_item.sv"
`include "rx_mac_scb.sv"
`include "rx_mac_agent.sv"

class rx_mac_env extends uvm_env;
    `uvm_component_utils(rx_mac_env)
    
    /* Component Handles */
    rx_mac_agent            agent;
    rx_mac_scb              scb;
    
    /* constructor */
    function new(string name = "env", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    /* Build phase - instantiate each of the components */
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = rx_mac_agent::type_id::create("agent", this);
        scb = rx_mac_scb::type_id::create("scb", this);
    endfunction : build_phase
    
    /* Connect phase - connect monitor analysis port to scoreboard */
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.mon_analysis_port.connect(scb.analysis_port);
    endfunction : connect_phase
    
endclass : rx_mac_env

`endif //_RX_MAC_ENV