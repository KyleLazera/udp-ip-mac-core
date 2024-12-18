`ifndef _WR_ITEM
`define _WR_ITEM

`include "async_fifo_pkg.svh"

class wr_item extends uvm_sequence_item;   
    /* Variables to randomize/pass through objects */
    rand bit wr_en;
    rand bit [7:0] wr_data;
    
   `uvm_object_utils_begin(wr_item)
      `uvm_field_int(wr_data, UVM_ALL_ON)
      `uvm_field_int(wr_en, UVM_ALL_ON)
   `uvm_object_utils_end
    
    constraint wr_const{wr_en dist {1 := 70, 0 := 30};}
    
    /* Constructor */
    function new(string name = "wr_item");
        super.new(name);
    endfunction : new
    
endclass : wr_item

`endif //_WR_ITEM