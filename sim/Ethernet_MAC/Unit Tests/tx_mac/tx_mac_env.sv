`ifndef _TX_MAC_ENV
`define _TX_MAC_ENV

`include "tx_mac_agent.sv"
`include "tx_mac_scb.sv"
`include "tx_mac_model.sv"

class tx_mac_env extends uvm_env;
    `uvm_component_utils(tx_mac_env)
    
    //Components
    tx_mac_agent        tx_agent;
    tx_mac_scb          tx_scb;
    tx_mac_model        model;
    
    /* TLM FIFO Ports to connect agents with scb/reference model */
    uvm_tlm_analysis_fifo#(tx_mac_trans_item) agent_model_fifo;
    uvm_tlm_analysis_fifo#(tx_mac_trans_item) model_scb_fifo;
    uvm_tlm_analysis_fifo#(tx_mac_trans_item) agent_scb_fifo;
        
    function new(string name = "tx_mac_env", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Init components
        tx_agent = tx_mac_agent::type_id::create("tx_mac_agent", this);
        tx_scb = tx_mac_scb::type_id::create("tx_mac_scb", this);
        model = tx_mac_model::type_id::create("tx_mac_model", this);
        //init TLM ports
        agent_model_fifo = new("agent_model_fifo", this);
        model_scb_fifo = new("model_scb_fifo", this);
        agent_scb_fifo = new("agent_scb_fifo", this);        
    endfunction : build_phase
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        //Connect the tx agent to the reference model
        tx_agent.a_port_drv.connect(agent_model_fifo.analysis_export);
        model.port.connect(agent_model_fifo.blocking_get_export);
        
        //Connect reference model to the scoreboard
        model.wr_ap.connect(model_scb_fifo.analysis_export);
        tx_scb.expected_data.connect(model_scb_fifo.blocking_get_export);
        
        //Connect the monitor to the scoreboard
        tx_agent.a_port_mon.connect(agent_scb_fifo.analysis_export);
        tx_scb.actual_data.connect(agent_scb_fifo.blocking_get_export);
        
    endfunction : connect_phase
    
    
endclass : tx_mac_env

`endif