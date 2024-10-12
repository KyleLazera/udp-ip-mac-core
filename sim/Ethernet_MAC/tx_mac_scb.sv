`ifndef _TX_MAC_SCB
`define _TX_MAC_SCB

`include "tx_mac_trans_item.sv"

class tx_mac_scb;
    //Mailbox from monitor
    mailbox scb_mbx;
    //Tag for debugging/printing
    string TAG = "Scoreboard";
    
    //Constructor
    function new(mailbox _mbx);
        scb_mbx = _mbx;
    endfunction : new
    
    task main();
        tx_mac_trans_item mon_item;
        logic [7:0] ethernet_frame[$];
        $display("[%s] Starting...", TAG);
        
        forever begin
            //Fetch data from queue
            scb_mbx.get(mon_item);
            ethernet_frame.push_back(mon_item.data_byte);
        end
                
    endtask : main

endclass : tx_mac_scb

`endif