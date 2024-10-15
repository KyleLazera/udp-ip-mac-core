`timescale 1ns / 1ps


module rx_mac
#(
    parameter DATA_WIDTH = 8,
    parameter IFG_SIZE = 12
)
(
    input wire clk,
    input wire reset_n,
    
    /* AXI Stream Output - FIFO */
    output wire [DATA_WIDTH-1:0] s_rx_axis_tdata,               //Data to transmit to asynch FIFO
    output wire m_rx_axis_tvalid,                               //Signal indicating module has data to transmit
    
    /* FIFO input/Control Signals */
    input wire s_rx_axis_trdy,                                  //FIFO indicating it is ready for data (not full/empty)
    
    /* RGMII Interface */
    input wire [DATA_WIDTH-1:0] rgmii_mac_rx_data,              //Input data from the RGMII PHY interface
    input wire rgmii_mac_rx_dv,                                 //Indicates data from PHY is valid
    input wire rgmii_mac_rx_er,                                 //Indicates an error in the data from the PHY
    
    /* Control Signals */
    input wire mii_select                                       //Indicates whether the data is coming in at SDR or DDR 
);



endmodule
