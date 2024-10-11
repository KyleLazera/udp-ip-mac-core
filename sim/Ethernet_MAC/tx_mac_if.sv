`ifndef _TX_MAC_IF
`define _TX_MAC_IF

interface tx_mac_if(input logic clk, input logic reset_n);
    /* AXI Stream Input - FIFO */
    logic [7:0] s_tx_axis_tdata;            //Incoming bytes of data from the FIFO    
    logic s_tx_axis_tvalid;                            //Indicates FIFO has valid data (is not empty)
    logic s_tx_axis_tlast;                             //Indicates last beat of transaction (final byte in packet)
    logic s_tx_axis_tkeep;                             //TODO: Determine if will be used
    logic s_tx_axis_tuser;                             //TODO: Determine if will be used
    
    /* AXI Stream Output - FIFO */
    logic s_tx_axis_trdy;                             //Indicates to FIFO that it can read data (used to set rd_en for FIFIO)
    
    /* RGMII Interface */
    logic rgmii_mac_tx_rdy;                            //Indicates the RGMII inteface is ready for data 
    logic [7:0] rgmii_mac_tx_data;         //Bytes to be transmitted to the RGMII
    logic rgmii_mac_tx_dv;                            //Indicates the data is valid 
    logic rgmii_mac_tx_er;                            //Indicates there is an error in the data
    
    /* Configurations */
    logic mii_select;                                  //Configures data rate (Double Data Rate (DDR) or Singale Data Rate (SDR))      
    

endinterface : tx_mac_if

`endif