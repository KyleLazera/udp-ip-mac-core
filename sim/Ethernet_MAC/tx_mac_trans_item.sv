`timescale 1ns / 1ps

`ifndef _TX_MAC_ITEM
`define _TX_MAC_ITEM

class tx_mac_trans_item;
    /* Variables to generate for the driver */
    rand logic [7:0] data_byte;
    rand int pckt_size;
    
    /* Variables to transmit from monitor to scb */
    logic [7:0] preamble [7:0];             //8 bytes of preamble
    logic [7:0] payload [$];                //payload size dependent upon pckt_size
    logic [7:0] fcs [3:0];                  //4 bytes of FCS
    
    
    //Constrains the number of bytes within a packet, the calculation for these numbers:
    //64 bytes minimum including src addr, dst addr, type/length, payload and 4 bytes of CRC
    //Remove the CRC as this will be generated, we only want to simulate Addresses, Type/Length & Payload 
    constraint pckt_size_const
    {
        pckt_size >= 60; //60
        pckt_size <= 70; //1500
    }
  
endclass : tx_mac_trans_item

`endif //_TX_MAC_ITEM