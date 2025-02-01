`ifndef ETH_MAC_ENV
`define ETH_MAC_ENV

`include "uvm_macros.svh"  // Import UVM macros
import uvm_pkg::*;         // Import all UVM classes

`include "eth_mac_wr_item.sv"
`include "eth_mac_scb.sv"
`include "eth_mac_virtual_seqr.sv"
`include "eth_mac_wr_agent.sv"
`include "eth_mac_wr_ref_model.sv"

class eth_mac_env extends uvm_env;
    `uvm_component_utils(eth_mac_env)

    /* Declare Agents & Components */
    eth_mac_wr_agent        wr_agent;
    eth_mac_wr_ref_model    wr_ref_model;
    eth_mac_scb             eth_scb;
    eth_mac_virtual_seqr    v_seqr;    

    /* Declare FIFO ports */
    uvm_tlm_analysis_fifo#(eth_mac_wr_item) wr_mon_scb;
    uvm_tlm_analysis_fifo#(eth_mac_wr_item) wr_agent_model;
    uvm_tlm_analysis_fifo#(eth_mac_wr_item) wr_ref_scb;

    function void new(string name = "eth_mac_env", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        /* Instantiate Agents*/
        wr_agent = eth_mac_wr_agent::type_id::create("wr_agent", this);
        eth_scb = eth_mac_scb::type_id::create("eth_scb", this);
        v_seqr = eth_mac_virtual_seqr::type_id::create("v_seqr", this);
        wr_ref_model = eth_mac_wr_ref_model::type_id::create("wr_ref_model", this);
        /* Instantiate FIFO's */
        wr_agent_model = new("wr_agent_model");
        wr_ref_scb = new("wr_ref_scb");
        wr_mon_scb = new("wr_mon_scb");
    endfunction : build_phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        //Connect write agent analysis port to export side of tlm fifo for scb
        wr_agent.a_port.connect(wr_mon_scb.analysis_export);
        eth_scb.eth_wr_import.connect(wr_mon_scb.blocking_get_export);

        //Connect agent and reference model via tlm fifo
        wr_agent.drv_a_port.connect(wr_agent_model.analysis_export);
        wr_ref_model.i_driver_port.connect(wr_agent_model.blocking_get_export);

        //Connect reference model to scoreboard
        wr_ref_model.o_scb_port.connect(wr_ref_scb.analysis_export);
        eth_scb.eth_wr_ref.connect(wr_ref_scb.blocking_get_export);

        //Connect virtual sequencers
        v_seqr.wr_vseqr = wr_agent.wr_seqr;

    endfunction : connect_phase

endclass : eth_mac_env

`endif //ETH_MAC_ENV