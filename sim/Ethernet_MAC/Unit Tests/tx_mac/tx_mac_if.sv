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
    
    //This task wiggles the pins that interact directly with the FIFO 
    task fifo_read_data(input tx_mac_trans_item item);
        
        // Drive the data to the DUT as long as there's data in the queue
        if (item.payload.size() > 0) begin
            s_tx_axis_tvalid <= 1'b1;
            s_tx_axis_tdata <= item.payload.pop_front();
            s_tx_axis_tlast <= item.last_byte.pop_front();
        end else begin
            s_tx_axis_tvalid <= 1'b0;
        end
    
        // Wait for signal propagation before the while loop
        @(posedge s_tx_axis_trdy);
    
        // Drive the data as long as there's data in the queue
        while (item.payload.size() > 0) begin
            //Wait for the next clock edge to drive data 
            @(posedge clk);
            //1 time unit delay - this allows the data to propogate through the DUT and s_tx_axis_trdy to be updated
            #1;
            // Check the ready signal to drive new data
            if (s_tx_axis_trdy) begin
                s_tx_axis_tvalid <= 1'b1;
                s_tx_axis_tdata <= item.payload.pop_front();
                s_tx_axis_tlast <= item.last_byte.pop_front();
            end
        end
    
        // Clear the valid and last signals after the last transaction
        @(posedge clk);
        
        //If we are operating in 10/100mbps mode, add an extra 
        if(mii_select)
            @(posedge clk);
        
        s_tx_axis_tvalid <= 1'b0;
        s_tx_axis_tlast <= 1'b0;
    endtask

    
    
    task rgmii_agent_sim(input tx_mac_trans_item item, input bit mii_sel);
        
        mii_select <= mii_sel;
        
        foreach(item.rgmii_ready[i]) begin 
            @(posedge clk);           
            rgmii_mac_tx_rdy = item.rgmii_ready[i];          
        end
    
    endtask : rgmii_agent_sim
    
    
    /* Initializes the FIFO signals */
    task init_fifo();
        s_tx_axis_tvalid <= 1'b0;
        s_tx_axis_tlast <= 1'b0;
        //rgmii_mac_tx_rdy <= 1'b0;
    endtask : init_fifo
    

endinterface : tx_mac_if

`endif