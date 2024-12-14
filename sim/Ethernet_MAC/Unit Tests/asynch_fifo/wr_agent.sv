`ifndef _WR_AGENT
`define _WR_AGENT

`include "async_fifo_pkg.svh"

class wr_agent extends uvm_agent;
    /* Register with factory */
    `uvm_component_utils(wr_agent)
    
    /* Components of agent */
    wr_sequencer    seqr;
    wr_driver       drv;
    wr_monitor      mon;
    
    /* Analysis port */
    uvm_analysis_port#(wr_item) a_port;
    
    /* Constructor */
    function new(string name = "wr_agent", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    /* Build Phase */
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Instantiate each component
        seqr = wr_sequencer::type_id::create("seqr", this);
        drv = wr_driver::type_id::create("drv", this);
        mon = wr_monitor::type_id::create("mon", this);
    endfunction : build_phase
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        //Connect seq export of driver and sequencer
        drv.seq_item_port.connect(seqr.seq_item_export);
        //assign mon analysis port
        a_port = mon.a_port;
    endfunction : connect_phase
    
endclass : wr_agent

`endif //_WR_AGENT
