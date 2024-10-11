`ifndef _TX_MAC_SCB
`define _TX_MAC_SCB

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
        $display("[%s] Starting...", TAG);
        
        forever begin
            //Fetch data from queue
            scb_mbx.get(mon_item);
            
            $display("%0h", mon_item.data_byte);
        end
                
    endtask : main

endclass : tx_mac_scb

`endif