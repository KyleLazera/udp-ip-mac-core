`ifndef _RX_MAC_RGMII_ITEM
`define _RX_MAC_RGMII_ITEM

`include "uvm_macros.svh"  // Import UVM macros
import uvm_pkg::*;         // Import all UVM classes

/*
 * This is the transaction item that is used to create the ethernet packet that will be recieved
 * by the RGMII PHY (this contains the byte of data, data valid signal and data error signal driven to DUT).
*/
class rx_mac_rgmii_item extends uvm_sequence_item;
    /* Utility macros - used to register class with factory & enable constructor definition*/
    `uvm_object_utils(rx_mac_rgmii_item)
    
    /* Variables */
    rand bit [7:0] data;                                        
    rand bit dv;
    rand bit er;      
     
    /* Constraints */   
    constraint rgmii_dv {dv dist {1 := 100, 0 := 0};}      //Distribution constraint for each dv
    constraint rgmii_er {er dist {1 := 0, 0 := 100};}      //Distribution constraint for each er   
    
    /* Constructor */
    function new(string name = "Item");
        super.new(name);
    endfunction : new
    
endclass : rx_mac_rgmii_item

`endif //_RX_MAC_RGMII_ITEM