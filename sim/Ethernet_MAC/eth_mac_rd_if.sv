`ifndef ETH_MAC_RD_IF
`define ETH_MAC_RD_IF

/*
 * This interface is used to simulate the ethernet module recieved data from the PHY, and then
 * reading the data from the rx fifo.
 */

interface eth_mac_rd_if
(
    input bit clk_125, 
    input bit clk90_125, 
    input bit reset_n
);
    /* Parameters */
    localparam RGMII_DATA_WIDTH = 4;
    localparam FIFO_DATA_WIDTH = 8;
    
    /* DUT Signals */
    //RGMII Write Signals
    logic rgmii_phy_rxc;                                   //Recieved ethernet clock signal
    logic [RGMII_DATA_WIDTH-1:0] rgmii_phy_rxd;            //Receieved data from PHY
    logic rgmii_phy_rxctl;                                 //Control signal (dv ^ er) from PHY
    //RX FIFO Signals 
    logic [FIFO_DATA_WIDTH-1:0] m_rx_axis_tdata;          //Data to transmit to asynch FIFO
    logic m_rx_axis_tvalid;                               //Signal indicating module has data to transmit
    logic m_rx_axis_tuser;                                //Used to indicate an error to the FIFO
    logic m_rx_axis_tlast;                                //Indicates last byte within a packet
    logic s_rx_axis_trdy;                                  //FIFO indicating it is ready for data (not full/empty)    


endinterface : eth_mac_rd_if

`endif // ETH_MAC_RD_IF