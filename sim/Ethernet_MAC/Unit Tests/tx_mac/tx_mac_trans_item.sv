`timescale 1ns / 1ps

`ifndef _TX_MAC_ITEM
`define _TX_MAC_ITEM

class tx_mac_trans_item;
    // Variables to generate for the driver 
    //rand logic [7:0] data_byte;
    //rand int pckt_size;
    
    logic [7:0] payload [$];                //This holds teh payload data (simulates the FIFO)
    logic last_byte [$];                    //This is a queue that holds the last byte data    
    
    // Variables to transmit from monitor to scb 
    logic [7:0] preamble [7:0];             //8 bytes of preamble
    logic [7:0] fcs [3:0];                  //4 bytes of FCS
    
  
endclass : tx_mac_trans_item

`endif //_TX_MAC_ITEM