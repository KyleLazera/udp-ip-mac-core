`ifndef _VIRTUAL_SEQUENCER
`define _VIRTUAL_SEQUENCER

`include "async_fifo_pkg.svh"

class virtual_sequencer extends uvm_sequencer;
    `uvm_component_utils(virtual_sequencer)
    
    /* Sequencer Instantiations */
    wr_sequencer v_wr_seqr;
    rd_sequencer v_rd_seqr;
    
    function new(string name = "virtual_sequencer",uvm_component parent);
        super.new(name, parent);
    endfunction    
    
endclass : virtual_sequencer

`endif //_VIRTUAL_SEQUENCER
