`ifndef _TX_MAC_DRIVER
`define _TX_MAC_DRIVER

`include "tx_mac_gen.sv"
`include "tx_mac_if.sv"
`include "tx_mac_cfg.sv"

class tx_mac_driver;
    tx_mac_cfg cfg;
    //Mailbox for communication
    mailbox drv_mbx;
    //Events for signaling
    event drv_done;
    //Virtual interface for DUT
    virtual tx_mac_if vif;
    //Tag for debugging/Logging
    string TAG = "Driver";
    
    //Constructor
    function new(mailbox _drv_mbx, event evt);
        drv_mbx = _drv_mbx;
        drv_done = evt;
    endfunction : new
    
    task main();
        tx_mac_trans_item rec_item;
        $display("[%s] Starting...", TAG);  
        
        //Init the RGMII & fifo Signals
        sim_rgmii();   
        
        forever begin                             
                                  
            /* Fetch payload from mailbox */
            drv_mbx.get(rec_item);       
            
            /* Raise the tvalid flag indicating there is data to transmit */
            if(rec_item.payload.size() > 0)                                 
                vif.s_tx_axis_tvalid = 1'b1;                              
            
            /* Only transmit data when the tx MAC asserts rdy flag */
            @(posedge vif.s_tx_axis_trdy);            
                              
            /* Drive a packet to the txmac (simulates FIFO driving data) */
            foreach(rec_item.payload[i]) begin
                @(posedge vif.clk);                  
                vif.s_tx_axis_tdata = rec_item.payload[i];
                vif.s_tx_axis_tlast = rec_item.last_byte[i];                   
                
                //If we are in MII mode, wait for the trdy flag to be raised again
                if(cfg.mii_sel)
                    @(posedge vif.s_tx_axis_trdy);               
            end
            
            /* Lower the last byte flag after a clock period */   
            vif.s_tx_axis_tlast = @(posedge vif.clk) 1'b0; 
            
            /* Clear the valid flag after last byte was sent */
            vif.s_tx_axis_tvalid = 1'b0;
            
            /* Indicate completion to generator */ 
            ->drv_done;          
        end
                   
    endtask : main
    
    //This function sets the signals from the RGMII module to inital value
    function sim_rgmii();
        //Simulate a 1000Mbps for now since this is teh targeted throughput. This
        //means driving the tx rdy signal at all times and pulling mii select low
        vif.mii_select = cfg.mii_sel;
        $display("[%s] MII Select Value: %0b", TAG, cfg.mii_sel);
        
        vif.rgmii_mac_tx_rdy = 1'b1;        
    endfunction : sim_rgmii    

endclass : tx_mac_driver

`endif