`timescale 1ns / 1ps

/* Top level module for ethernet mac that contains writable and readable FIFO's */

module ethernet_mac_fifo
#(
    parameter FLOW_CONTROL = 1, 
    /* These Parameters are not meant to be adjusted */
    parameter FIFO_DATA_WIDTH = 9,
    parameter AXI_DATA_WIDTH = 8,
    parameter RGMII_DATA_WIDTH = 4,
    parameter RX_FIFO_DEPTH = 8192, 
    parameter TX_FIFO_DEPTH = 4096  
)
(
    input wire i_clk,                                           //System clock to read data from rx and tx FIFO's - 100MHz
    input wire clk_125,                                         //Used to drive the tx MAC and RGMII interface 
    input wire clk90_125,                                       //Used to transmit signals on RGMII 
    input wire i_reset_n,                                       //Active low synchronous reset

    /* External PHY Interface Signals */
    input wire rgmii_phy_rxc,                                   //Recieved ethernet clock signal
    input wire [RGMII_DATA_WIDTH-1:0] rgmii_phy_rxd,            //Receieved data from PHY
    input wire rgmii_phy_rxctl,                                 //Control signal (dv ^ er) from PHY
    output wire rgmii_phy_txc,                                  //Outgoing data clock signal
    output wire [RGMII_DATA_WIDTH-1:0] rgmii_phy_txd,           //Outgoing ethernet packet data
    output wire rgmii_phy_txctl,                                //Outgoing control signal (dv ^ er)    

    /* Tx FIFO - AXI interface*/
    input wire [AXI_DATA_WIDTH-1:0] s_tx_axis_tdata,            //Tx word to send via ethernet  
    input wire s_tx_axis_tvalid,                                //Write enable signal into the tx FIFO
    input wire s_tx_axis_tlast,                                 //Indicates the final byte within a packet
    output wire m_tx_axis_trdy,                                 //Indicates the tx FIFO is not full/has space to store data

    /* Rx FIFO - AXI Interface*/
    output wire [AXI_DATA_WIDTH-1:0] m_rx_axis_tdata,            //Rx data receieved from ethernet MAC   
    output reg m_rx_axis_tvalid,                                //Indicates rx FIFO is not empty and has data 
    output wire m_rx_axis_tlast,                                 //Indicates last beat of transaction (final byte in packet)
    input wire s_rx_axis_trdy                                    //Acts as a read enable signal to rx fifo   
);

/****************************************************************
Intermediary Signals
*****************************************************************/

wire mii_mode;

/* RX FIFO */
wire rx_clk;
wire [AXI_DATA_WIDTH-1:0] rx_mac_data;
wire rx_mac_last;
wire rx_mac_data_valid;
wire rx_mac_tuser_error;
wire rx_fifo_rdy;

/* TX FIFO */
wire [AXI_DATA_WIDTH-1:0] tx_fifo_tdata;
wire tx_fifo_tlast;
wire tx_fifo_tvalid;
wire tx_mac_trdy;

/****************************************************************
Ethernet MAC Instantiation
*****************************************************************/

ethernet_mac#(
    .FIFO_DATA_WIDTH(8), 
    .RGMII_DATA_WIDTH(RGMII_DATA_WIDTH),
    .FLOW_CONTROL(FLOW_CONTROL)
    )
tri_speed_eth_mac (
    .clk_125(clk_125),
    .clk90_125(clk90_125),
    .reset_n(i_reset_n),
    //External PHY Interface
    .rgmii_phy_rxc(rgmii_phy_rxc),
    .rgmii_phy_rxd(rgmii_phy_rxd),
    .rgmii_phy_rxctl(rgmii_phy_rxctl),
    .rgmii_phy_txc(rgmii_phy_txc),
    .rgmii_phy_txd(rgmii_phy_txd),
    .rgmii_phy_txctl(rgmii_phy_txctl),
    //TX FIFO - AXI Interface
    .s_tx_axis_tdata(tx_fifo_tdata),
    .s_tx_axis_tvalid(tx_fifo_tvalid), 
    .s_tx_axis_tlast(tx_fifo_tlast),
    .s_tx_axis_trdy(tx_mac_trdy),
    //RX FIFO - AXI Interface
    .rgmii_rxc(rx_clk),
    .m_rx_axis_tdata(rx_mac_data),
    .m_rx_axis_tvalid(rx_mac_data_valid),
    .m_rx_axis_tuser(rx_mac_tuser_error),
    .m_rx_axis_tlast(rx_mac_last),
    .s_rx_axis_trdy(rx_fifo_rdy), 
    //Control Signal(s)
    .mii_mode(mii_mode)
    );


/*****************************************************************
RX FIFO Instantiation
******************************************************************/

axi_async_fifo #(
    .AXI_DATA_WIDTH(8),
    .PIPELINE_STAGES(2),
    .FIFO_ADDR_WIDTH(13) 
) rx_fifo (
    /* AXI Master - Output Signals / Read Side */
    .m_aclk(i_clk),
    .m_sresetn(i_reset_n),
    .m_axis_tdata(m_rx_axis_tdata),
    .m_axis_tlast(m_rx_axis_tlast),
    .m_axis_tvalid(m_rx_axis_tvalid),
    .m_axis_trdy(s_rx_axis_trdy),

    /* AXI Slave - Input Signals / Write Side*/
    .s_aclk(rx_clk),
    .s_sresetn(i_reset_n),
    .s_axis_tdata(rx_mac_data),
    .s_axis_tlast(rx_mac_last),
    .s_axis_tvalid(rx_mac_data_valid),
    .s_axis_tuser(rx_mac_tuser_error),
    .s_axis_trdy(rx_fifo_rdy)    
);

/*****************************************************************
TX FIFO Instantiation
*****************************************************************/

axi_async_fifo #(
    .AXI_DATA_WIDTH(8),
    .PIPELINE_STAGES(2),
    .FIFO_ADDR_WIDTH(12)
) tx_fifo (
    /* AXI Master - Output Signals */
    .m_aclk(clk_125),
    .m_sresetn(i_reset_n),
    .m_axis_tdata(tx_fifo_tdata),
    .m_axis_tlast(tx_fifo_tlast),
    .m_axis_tvalid(tx_fifo_tvalid),
    .m_axis_trdy(tx_mac_trdy),

    /* AXI Slave - Input Signals */
    .s_aclk(i_clk),
    .s_sresetn(i_reset_n),
    .s_axis_tdata(s_tx_axis_tdata),
    .s_axis_tlast(s_tx_axis_tlast),
    .s_axis_tvalid(s_tx_axis_tvalid),
    .s_axis_tuser(1'b0),
    .s_axis_trdy(m_tx_axis_trdy)    
);


endmodule : ethernet_mac_fifo

