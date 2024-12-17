`ifndef _RD_AGENT
`define _RD_AGENT

`include "async_fifo_pkg.svh"

class rd_agent extends uvm_agent;
    `uvm_component_utils(rd_agent)
    
    /* Component instances */
    rd_sequencer        seqr;
    rd_driver           drv;
    rd_monitor          mon;
    
    /* Analysis Port */
    uvm_analysis_port#(wr_item) a_port;
    
    function new(string name = "rd_agent", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Instantiate each component
        seqr = rd_sequencer::type_id::create("seqr", this);
        drv = rd_driver::type_id::create("drv", this);
        mon = rd_monitor::type_id::create("mon", this);
    endfunction : build_phase
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        //Connect sequencer export to the driver
        drv.seq_item_port.connect(seqr.seq_item_export);
        //Assign analysis port
        a_port = mon.a_port;     
    endfunction : connect_phase
    
endclass : rd_agent

`endif //_RD_AGENT