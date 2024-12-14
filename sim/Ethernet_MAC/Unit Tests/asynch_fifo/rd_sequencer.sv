`ifndef _RD_SEQR
`define _RD_SEQR

`include "async_fifo_pkg.svh"

class rd_sequencer extends uvm_sequencer#(rd_item);
    /* Register with factory */
    `uvm_component_utils(rd_sequencer)
    
    /* Constructor */
    function new(string name = "rd_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction : new    
endclass : rd_sequencer

`endif //_RD_SEQR