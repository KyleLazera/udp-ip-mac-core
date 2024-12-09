`ifndef _WR_ITEM
`define _WR_ITEM

`include "async_fifo_pkg.svh"

class wr_item extends uvm_sequence_item;
    /* Register sequence item with factory */
    `uvm_object_utils(wr_item)
    
    /* Variables to randomize/pass through objects */
    rand bit [7:0] wr_data;
    
    /* Constructor */
    function new(string name = "wr_item");
        super.new(name);
    endfunction : new
    
endclass : wr_item

`endif //_WR_ITEM