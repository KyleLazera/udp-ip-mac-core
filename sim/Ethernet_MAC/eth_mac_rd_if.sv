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
    input bit clk_100,
    input bit reset_n
);
    /* Parameters */
    localparam RGMII_DATA_WIDTH = 4;
    localparam FIFO_DATA_WIDTH = 8;
    
    /* DUT Signals */
    //RGMII Write Signals
    logic rgmii_phy_rxc;                                   
    logic [RGMII_DATA_WIDTH-1:0] rgmii_phy_rxd;            
    logic rgmii_phy_rxctl;                                 
    //RX FIFO Signals 
    logic [FIFO_DATA_WIDTH-1:0] m_rx_axis_tdata;          
    logic m_rx_axis_tvalid;                               
    logic m_rx_axis_tuser;                                
    logic m_rx_axis_tlast;                                
    logic s_rx_axis_trdy;                                    

    //todo: This needs to support also mbps (SDR)
    task rgmii_drive_data(bit[7:0] rx_data[$]);
        while(rx_data.size() != 0) begin
            bit[7:0] data_byte = rx_data.pop_front();
            @(posedge rgmii_phy_rxc);
            rgmii_phy_rxd <= data_byte[3:0];
            rgmii_phy_rxctl <= 1'b1;
            @(negedge rgmii_phy_rxc);
            rgmii_phy_rxd <= data_byte[7:4];
            rgmii_phy_rxctl <= 1'b1;
        end
    endtask : rgmii_drive_data

    //todo : Must be parametarizable for the period
    task generate_clock();
        rgmii_phy_rxc <= 0;
        forever 
            #4 rgmii_phy_rxc <= ~rgmii_phy_rxc;
    endtask : generate_clock

    //todo: See if there can be improvement on this function
    task read_rx_fifo(bit [7:0] rx_fifo[$]);
        @(posedge clk_100);
        s_rx_axis_trdy <= 1'b1;
        while(m_rx_axis_tvalid) begin
            @(posedge clk_100);
            rx_fifo.push_back(m_rx_axis_tdata);
        end
    endtask : read_rx_fifo

endinterface : eth_mac_rd_if

`endif // ETH_MAC_RD_IF