`ifndef _TX_MAC_IF
`define _TX_MAC_IF

`include "tx_mac_trans_item.sv"

interface tx_mac_if(input logic clk, input logic reset_n);
    /* AXI Stream Input - FIFO */
    logic [7:0] s_tx_axis_tdata;                        //Incoming bytes of data from the FIFO    
    logic s_tx_axis_tvalid;                            //Indicates FIFO has valid data (is not empty)
    logic s_tx_axis_tlast;                             //Indicates last beat of transaction (final byte in packet)
    logic s_tx_axis_tkeep;                             //TODO: Determine if will be used
    logic s_tx_axis_tuser;                             //TODO: Determine if will be used
    
    /* AXI Stream Output - FIFO */
    logic s_tx_axis_trdy;                             //Indicates to FIFO that it can read data (used to set rd_en for FIFIO)
    
    /* RGMII Interface */
    logic rgmii_mac_tx_rdy;                            //Indicates the RGMII inteface is ready for data 
    logic [7:0] rgmii_mac_tx_data;                     //Bytes to be transmitted to the RGMII
    logic rgmii_mac_tx_dv;                            //Indicates the data is valid 
    logic rgmii_mac_tx_er;                            //Indicates there is an error in the data
    
    /* Configurations */
    logic mii_select;                                  //Configures data rate (Double Data Rate (DDR) or Singale Data Rate (SDR))      
    
    /* Tasks to write data to the Signals */
    
    task drive_data(input tx_mac_trans_item item, bit mii_sel);
        
        mii_select <= mii_sel;
        
        if(!mii_sel)
            rgmii_mac_tx_rdy <= 1'b1;            
                    
        // Raise the tvalid flag indicating there is data to transmit /
        if(item.payload.size() > 0)                                 
            s_tx_axis_tvalid <= 1'b1;                              
        
        // Only transmit data when the tx MAC asserts rdy flag 
        @(posedge s_tx_axis_trdy);            
                          
        // Drive a packet to the txmac (simulates FIFO driving data) 
        foreach(item.payload[i]) begin                              
            s_tx_axis_tdata <= item.payload[i];
            s_tx_axis_tlast <= item.last_byte[i];                   
            @(posedge clk);
            
            //If we are in MII mode, wait for the trdy flag to be raised again
            if(mii_sel)
                @(posedge s_tx_axis_trdy);               
        end
        
        // Lower the last byte flag after a clock period    
        s_tx_axis_tlast <= 1'b0; 
        
        // Clear the valid flag after last byte was sent 
        s_tx_axis_tvalid <= 1'b0;     
           
    endtask : drive_data
    
    /* Initializes the FIFO signals */
    task init_fifo();
        s_tx_axis_tvalid <= 1'b0;
        s_tx_axis_tlast <= 1'b0;
    endtask : init_fifo
    
    task monitor_output_data(tx_mac_trans_item item);
        
            
        
       
    endtask : monitor_output_data

endinterface : tx_mac_if

`endif