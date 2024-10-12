`ifndef _TX_MAC_DRIVER
`define _TX_MAC_DRIVER

`include "tx_mac_gen.sv"
`include "tx_mac_if.sv"

class tx_mac_driver;
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
        int byte_ctr = 0;
        $display("[%s] Starting...", TAG);  
        
        //Init the RGMII & fifo Signals
        sim_rgmii();   
        sim_fifo();
        
        @(posedge vif.s_tx_axis_trdy);
        
        forever begin        
            
            if(vif.s_tx_axis_trdy) begin
                //Fetch data from mailbox 
                drv_mbx.get(rec_item);
                
                @(posedge vif.clk);
                
                //Count the packet sent - used to identify last packet to raise the last flag 
                byte_ctr++;  
                
                //Check to see if this is last byte in packet
                if(byte_ctr == (rec_item.pckt_size)) begin
                    vif.s_tx_axis_tlast = 1'b1; 
                    //Send byte to interface if ready signal is high
                    vif.s_tx_axis_tdata = rec_item.data_byte;
                    //Wait for teh next clock edge to lower the last signal
                    @(posedge vif.clk);
                    vif.s_tx_axis_tlast = 1'b0; 
                    //indicate driver has succesfully transmitted data
                    ->drv_done;                                 
                end else begin
                    vif.s_tx_axis_tlast = 1'b0;
                    //Send byte to interface if ready signal is high
                    vif.s_tx_axis_tdata = rec_item.data_byte;
                    //indicate driver has succesfully transmitted data
                    ->drv_done;                              
                end
            end
        end
                   
    endtask : main
    
    //This function simulates the signals from the RGMII module
    function sim_rgmii();
        //Simulate a 1000Mbps for now since this is teh targeted throughput. This
        //means driving the tx rdy signal at all times and pulling mii select low
        vif.mii_select = 1'b0;
        vif.rgmii_mac_tx_rdy = 1'b1;        
    endfunction : sim_rgmii    
    
    //This function simulates the signals from the FIFO module
    function sim_fifo();
         //For now indicate there is always valid data in the FIFO (Never empty)
         vif.s_tx_axis_tvalid = 1'b1;
    endfunction : sim_fifo

endclass : tx_mac_driver

`endif