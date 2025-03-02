`timescale 1ns / 1ps

/* Top level module for ethernet mac that contains writable and readable FIFO's */

module ethernet_mac_fifo
#(
    parameter FIFO_DATA_WIDTH = 9,   // Data width of each word in the FIFO
    parameter FIFO_DEPTH = 256,      // Depth of tx and rx FIFO's
    parameter AXI_DATA_WIDTH = 8,    // Data width of teh axi data lines
    parameter RGMII_DATA_WIDTH = 4   // Data width for RGMII data line 
)
(
    input wire i_clk,                                           //System clock to read data from rx and tx FIFO's
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
    input wire [AXI_DATA_WIDTH-1:0] m_tx_axis_tdata,           //Tx word to send via ethernet  
    input wire m_tx_axis_tvalid,                                //Behaves as a write enable signal into the ethernet mac
    input wire m_tx_axis_tlast,                                 //Indicates the final byte within a packet
    output wire s_tx_axis_trdy,                                 //Indicates the tx FIFO is not almost full/has space to write data

    /* Rx FIFO - AXI Interface*/
    output wire [AXI_DATA_WIDTH-1:0] m_rx_axis_tdata,           //Rx data receieved from ethernet MAC   
    output wire m_rx_axis_tvalid,                                //Indicates rx FIFO is not empty and has data 
    output wire m_rx_axis_tlast,                                 //Indicates last beat of transaction (final byte in packet)
    input wire s_rx_axis_trdy                                    //Acts as a read enable signal to rx fifo   
);

/****************************************************************
Intermediary Logic
*****************************************************************/
/* TX FIFO */
wire tx_fifo_full;
wire tx_fifo_almost_full;
wire tx_fifo_empty;
wire tx_fifo_almost_empty;
wire tx_fifo_not_full;
wire tx_fifo_not_empty;

wire [FIFO_DATA_WIDTH-1:0] tx_fifo_data_out;
wire tx_fifo_rd_en;

assign tx_fifo_not_full = ~tx_fifo_almost_full; //| ~tx_fifo_full 
assign tx_fifo_not_empty = ~tx_fifo_empty; //& ~tx_fifo_almost_empty

/* RX FIFO */
wire rx_clk;
wire rx_mac_data;
wire rx_mac_last;
wire rx_mac_data_valid;

wire rx_fifo_full;
wire rx_fifo_almost_full;
wire rx_fifo_empty;
wire rx_fifo_almost_empty;
wire rx_fifo_not_full;
wire rx_fifo_not_empty;

assign rx_fifo_not_full = ~rx_fifo_full & ~rx_fifo_almost_full;
assign rx_fifo_not_empty = ~rx_fifo_empty & ~rx_fifo_almost_empty;

/****************************************************************
Output Logic
*****************************************************************/

assign s_tx_axis_trdy = tx_fifo_not_full;
assign m_rx_axis_tvalid = rx_fifo_not_empty;

/****************************************************************
Module Instantiations 
*****************************************************************/

ethernet_mac#(
    .FIFO_DATA_WIDTH(8), 
    .RGMII_DATA_WIDTH(RGMII_DATA_WIDTH)
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
    .s_tx_axis_tdata(tx_fifo_data_out[FIFO_DATA_WIDTH-1:1]),
    .s_tx_axis_tvalid(tx_fifo_not_empty),
    .s_tx_axis_tlast(tx_fifo_data_out[0]),
    .s_tx_axis_trdy(tx_fifo_rd_en),
    //RX FIFIO - AXI Interface
    .rgmii_rxc(rx_clk),
    .m_rx_axis_tdata(rx_mac_data),
    .m_rx_axis_tvalid(rx_mac_data_valid),
    .m_rx_axis_tuser(),
    .m_rx_axis_tlast(rx_mac_last),
    .s_rx_axis_trdy(rx_fifo_not_full)
    );

fifo#(
    .DATA_WIDTH(FIFO_DATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH)
) tx_fifo (
    .clk_wr(i_clk),
    .clk_rd(clk_125),
    .reset_n(i_reset_n),
    .data_in({m_tx_axis_tdata, m_tx_axis_tlast}),
    .write_en(m_tx_axis_tvalid),
    .data_out(tx_fifo_data_out),
    .read_en(tx_fifo_rd_en),
    .empty(tx_fifo_empty),
    .almost_empty(tx_fifo_almost_empty),
    .full(tx_fifo_full),
    .almost_full(tx_fifo_almost_full)
);

fifo#(
    .DATA_WIDTH(FIFO_DATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH)
) rx_fifo (
    .clk_wr(rx_clk),
    .clk_rd(i_clk),
    .reset_n(i_reset_n),
    .data_in({rx_mac_data, rx_mac_last}),
    .write_en(rx_mac_data_valid),
    .data_out({m_rx_axis_tdata, m_rx_axis_tlast}),
    .read_en(s_rx_axis_trdy),
    .empty(rx_fifo_empty),
    .almost_empty(rx_fifo_almost_empty),
    .full(rx_fifo_full),
    .almost_full(rx_fifo_almost_full)
);

endmodule : ethernet_mac_fifo

