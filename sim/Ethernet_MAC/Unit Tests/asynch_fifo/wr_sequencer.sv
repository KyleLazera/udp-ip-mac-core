`ifndef _WR_SEQUENCER
`define _WR_SEQUENCER

`include "async_fifo_pkg.svh"

class wr_sequencer extends uvm_sequencer #(wr_item);
    /* Register with factory */
    `uvm_component_utils(wr_sequencer)
    
    /* Constructor */
    function new(string name = "wr_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
endclass : wr_sequencer

`endif //_WR_SEQUENCER
