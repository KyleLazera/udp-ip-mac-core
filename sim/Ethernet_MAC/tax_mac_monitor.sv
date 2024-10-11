`ifndef _TX_MAC_MONITOR
`define _TX_MAC_MONITOR

`include "tx_mac_trans_item.sv"

class tx_mac_monitor;
    //Mailbox for scoreboard communication
    mailbox scb_mbx;
    //Virtual interface
    virtual tx_mac_if vif;
    //Tag for debugging/printing
    string TAG = "Monitor";
    
    //Constructor
    function new(mailbox _mbx);
        scb_mbx = _mbx;
    endfunction : new  
    
    task main();
        tx_mac_trans_item rec_item = new;
        bit pckt_synch = 1'b0;
        $display("[%s] Starting...", TAG);
        
        forever begin
            //Sample teh data being transmitted to the RGMII on every clock pulse
            @(posedge vif.clk);
            rec_item.data_byte = vif.rgmii_mac_tx_data;        
            //Transmit this data to the scoreboard
            scb_mbx.put(rec_item);
        end
        
    endtask : main 
    
endclass : tx_mac_monitor

`endif
