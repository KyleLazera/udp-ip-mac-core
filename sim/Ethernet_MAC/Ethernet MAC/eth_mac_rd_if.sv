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
    bit rgmii_phy_rxc;                                   
    bit [RGMII_DATA_WIDTH-1:0] rgmii_phy_rxd;            
    bit rgmii_phy_rxctl;                                 
    //RX FIFO Signals 
    bit [FIFO_DATA_WIDTH-1:0] m_rx_axis_tdata;          
    bit m_rx_axis_tvalid;                               
    bit m_rx_axis_tuser;                                
    bit m_rx_axis_tlast;                                
    bit s_rx_axis_trdy;                                    

    task rgmii_drive_data(bit[7:0] rx_data[$], bit [1:0] link_speed);
        while(rx_data.size() != 0) begin
            bit[7:0] data_byte = rx_data.pop_front();
            @(posedge rgmii_phy_rxc);
            rgmii_phy_rxd <= data_byte[3:0];
            rgmii_phy_rxctl <= 1'b1;

            if(link_speed == 2'b00)
                @(negedge rgmii_phy_rxc);
            else
                @(posedge rgmii_phy_rxc);
            
            rgmii_phy_rxd <= data_byte[7:4];
            rgmii_phy_rxctl <= 1'b1;
        end

        //Transmit interframe gap (12 bytes worth of data)
        repeat(24) begin
            @(posedge rgmii_phy_rxc);
            rgmii_phy_rxctl <= 1'b0;
            rgmii_phy_rxd <= 4'h0;
        end

    endtask : rgmii_drive_data

    task generate_clock(bit [1:0] mode);
        int period;        

        /* Determine the clock period based on the mode */
        case(mode) 
            2'b00: period = 4;     //Gbit - 8ns clock period
            2'b01: period = 20;     //100 mbps - 40ns clock period
            2'b10: period = 200;    //10mbps - 400ns clock period
            default : period = 4;
        endcase

        rgmii_phy_rxc <= 0;
        forever 
            #(period) rgmii_phy_rxc <= ~rgmii_phy_rxc; 
    
    endtask : generate_clock

    task read_rx_fifo(ref bit [7:0] rx_fifo[$]);
        s_rx_axis_trdy <= 1'b1;
        @(m_rx_axis_tvalid);   
        while(!m_rx_axis_tlast) begin                 
            #1;
            if(m_rx_axis_tvalid) begin       
                rx_fifo.push_back(m_rx_axis_tdata);                
            end
            @(posedge rgmii_phy_rxc);
        end

        //Wait for tvalid signal to go low
        @(negedge m_rx_axis_tvalid);
    endtask : read_rx_fifo

endinterface : eth_mac_rd_if

`endif // ETH_MAC_RD_IF