`ifndef _RD_ITEM
`define _RD_ITEM

`include "async_fifo_pkg.svh"

class rd_item extends uvm_sequence_item;

    /* Variables */
    rand bit read_en;
    
    /* Register with factory */
    `uvm_object_utils_begin(rd_item)
        `uvm_field_int(read_en, UVM_ALL_ON) //Enable copy, print etc...
    `uvm_object_utils_end
    
    /* Constructor */
    function new(string name = "rd_item");
        super.new(name);
    endfunction : new
    
endclass : rd_item

`endif //_RD_ITEM
