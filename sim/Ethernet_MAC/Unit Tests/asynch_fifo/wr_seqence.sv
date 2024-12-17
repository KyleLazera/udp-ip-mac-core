`ifndef _WR_SEQ
`define _WR_SEQ

`include "async_fifo_pkg.svh"
`include "wr_item.sv"

class wr_sequence extends uvm_sequence#(wr_item);
    /* Register with factory */
    `uvm_object_utils(wr_sequence)
    
    /* Constructor */
    function new(string name = "wr_sequence");
        super.new(name);
    endfunction : new
    
    virtual task body();
        wr_item data;
        `uvm_do(data)     
        
    endtask : body
    
endclass : wr_sequence

`endif //_WR_SEQ