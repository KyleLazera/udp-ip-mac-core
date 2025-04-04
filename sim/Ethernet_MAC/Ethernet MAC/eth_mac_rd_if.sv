`ifndef ETH_MAC_RD_IF
`define ETH_MAC_RD_IF

/*
 * This interface is used to simulate the ethernet module recieved data from the PHY, and then
 * reading the data from the rx fifo.
 */

interface eth_mac_rd_if
(
    input bit clk_100,
    input bit reset_n
);
    /* Parameters */
    localparam RGMII_DATA_WIDTH = 4;
    localparam AXI_DATA_WIDTH = 8;
    
    /* DUT Signals */
    //RGMII Write Signals
    bit rgmii_phy_rxc;                                   
    bit [RGMII_DATA_WIDTH-1:0] rgmii_phy_rxd;            
    bit rgmii_phy_rxctl;                                 
    //RX FIFO Signals 
    bit [AXI_DATA_WIDTH-1:0] m_rx_axis_tdata;          
    bit m_rx_axis_tvalid;                                                              
    bit m_rx_axis_tlast;                                
    bit s_rx_axis_trdy;                                    

    task rgmii_drive_data(bit[7:0] rx_data[$], bit [1:0] link_speed, bit data_err, output bit bad_pckt);
        int data_not_valid = 1'b0;
        bad_pckt = 1'b0;
        
        while(rx_data.size() != 0) begin
            bit[7:0] data_byte = rx_data.pop_front();
            data_not_valid = $urandom_range(1, 1000);
            @(posedge rgmii_phy_rxc);
            rgmii_phy_rxd <= data_byte[3:0];
            //rgmii_phy_rxctl <= 1'b1;

            rgmii_phy_rxctl <= (data_err) ? (data_not_valid != 1) : 1'b1;
            if(data_err & data_not_valid == 1)
                bad_pckt = 1'b1;

            if(link_speed == 2'b00) begin
                @(negedge rgmii_phy_rxc);
            end else begin
                @(posedge rgmii_phy_rxc);            
            end

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
        bit first_byte = 1'b1;

        //Indicate to the rx FIFO that we are ready to recieve data 
        s_rx_axis_trdy <= 1'b1;

        //Sample data until we reach the last byte within a packet
        while(1) begin                 
            #1;
            //only sample the data if the FIFO indicates it is not empty 
            if(m_rx_axis_tvalid & m_rx_axis_tlast) begin       
                rx_fifo.push_back(m_rx_axis_tdata);  
                break;             
            end else if(m_rx_axis_tvalid) begin
                rx_fifo.push_back(m_rx_axis_tdata);
            end 

            @(posedge clk_100);
        end

        @(posedge clk_100);

        //Lower the trdy flag to halt the FIFO temporarily - this is meant to simulate
        // processing time between each read
        s_rx_axis_trdy <= 1'b0;

        repeat(2)
            @(posedge clk_100);

        first_byte = 1'b1;

    endtask : read_rx_fifo

endinterface : eth_mac_rd_if

`endif // ETH_MAC_RD_IF