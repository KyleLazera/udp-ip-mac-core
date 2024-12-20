`ifndef _TX_MAC_ITEM
`define _TX_MAC_ITEM

class tx_mac_trans_item extends uvm_sequence_item;
    `uvm_object_utils(tx_mac_trans_item)
    
    logic [7:0] payload [$];                //This holds teh payload data (simulates a FIFO)
    logic last_byte [$];                    //This is a queue that holds the last byte data  
    
   `uvm_object_utils_begin(tx_mac_trans_item)
      `uvm_field_int(payload, UVM_ALL_ON)
      `uvm_field_int(last_byte, UVM_ALL_ON)
   `uvm_object_utils_end      
    
    // Variables to transmit from monitor to scb 
    logic [7:0] preamble [7:0];             //8 bytes of preamble
    logic [7:0] fcs [3:0];                  //4 bytes of FCS
    
    function new(string name = "tx_mac_trans_item");
        super.new(name);
    endfunction : new
  
endclass : tx_mac_trans_item

`endif //_TX_MAC_ITEM