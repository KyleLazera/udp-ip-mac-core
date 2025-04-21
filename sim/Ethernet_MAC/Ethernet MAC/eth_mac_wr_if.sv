`ifndef ETH_MAC_WR_IF
`define ETH_MAC_WR_IF

/* 
 * This interface is used to simulate users writing data into the tx fifo and read/monitor
 * the output signals on the RGMII signals 
 */


interface eth_mac_wr_if
(
    input bit clk_100,                                  //100MHz clock input to tx FIFO
    input bit reset_n
);  
    /* Parameters */
    localparam RGMII_DATA_WIDTH = 4;
    localparam AXI_DATA_WIDTH = 8;
    
    /* DUT Signals */
    //RGMII Read Signals
    logic rgmii_phy_txc;                                  //Outgoing data clock signal
    logic [RGMII_DATA_WIDTH-1:0] rgmii_phy_txd;           //Outgoing ethernet packet data
    logic rgmii_phy_txctl;                                //Outgoing control signal (dv ^ er)
    //TX FIFO Signals 
    bit [AXI_DATA_WIDTH-1:0] m_tx_axis_tdata;            //Bytes being written into the Tx FIFO   
    bit m_tx_axis_tvalid;                                //Write enable for the tx fifo
    bit m_tx_axis_tlast;                                 //Indicates last beat of transaction (final byte in packet)
    bit s_tx_axis_trdy;                                  //Indicates the FIFO is not full and can receieve data

    /* BFM Tasks */
    
    task tx_fifo_drive_data(bit [7:0] ref_fifo[$], bit last_packet);
        int fifo_size = ref_fifo.size();
    
        // Begin driving data
        while (fifo_size > 0) begin
            m_tx_axis_tvalid <= 1'b1;
            m_tx_axis_tdata  <= ref_fifo.pop_back();
            m_tx_axis_tlast  <= (fifo_size == 1);  // last signal on final byte
    
            // Wait for valid handshake
            do @(posedge clk_100); while (!s_tx_axis_trdy);
    
            fifo_size--;
        end
    
        // After the final valid transfer
        if (last_packet) begin
            // Create a break in the stream (deassert valid)
            m_tx_axis_tvalid <= 1'b0;
            m_tx_axis_tlast  <= 1'b0;
            m_tx_axis_tdata  <= 8'b0;
            @(posedge clk_100);  // hold valid low for 1 cycle
        end else begin
            // Keep valid high to indicate stream is still active
            m_tx_axis_tlast <= 1'b0;
        end
    endtask : tx_fifo_drive_data


    task read_rgmii_data(ref bit[7:0] rgmii_data[$], bit [1:0] link_speed);
        @(posedge rgmii_phy_txctl);
        while (rgmii_phy_txctl) begin
            logic [3:0] lower_nibble, upper_nibble;
            logic [7:0] sampled_byte;
            
            @(posedge rgmii_phy_txc);

            if(rgmii_phy_txctl) begin
                lower_nibble = rgmii_phy_txd;

                if(link_speed == 2'b00)
                    @(negedge rgmii_phy_txc);  
                else
                    @(posedge rgmii_phy_txc);

                upper_nibble = rgmii_phy_txd;
                sampled_byte = {upper_nibble, lower_nibble};            
                rgmii_data.push_back(sampled_byte);
            end
        end
        
    endtask : read_rgmii_data

endinterface : eth_mac_wr_if

`endif // ETH_MAC_WR_IF