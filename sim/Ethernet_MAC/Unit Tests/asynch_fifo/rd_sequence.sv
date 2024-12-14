`ifndef _RD_SEQ
`define _RD_SEQ

`include "async_fifo_pkg.svh"
`include "rd_item.sv"

class rd_sequence extends uvm_sequence#(rd_item);
    `uvm_object_utils(rd_sequence)
    
    function new(string name = "rd_sequence");
        super.new(name);
    endfunction : new
    
    virtual task body();
        rd_item read_en;
        `uvm_do(read_en);
    endtask : body
    
endclass : rd_sequence

`endif //_RD_SEQ
