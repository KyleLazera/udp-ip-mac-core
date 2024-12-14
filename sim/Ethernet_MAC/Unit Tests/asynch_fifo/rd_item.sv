`ifndef _RD_ITEM
`define _RD_ITEM

`include "async_fifo_pkg.svh"

class rd_item extends uvm_sequence_item;
    /* Register with factory */
    `uvm_object_utils(rd_item)
    
    /* Variables */
    rand bit read_en;
    
    /* Constructor */
    function new(string name = "rd_item");
        super.new(name);
    endfunction : new
    
endclass : rd_item

`endif //_RD_ITEM
