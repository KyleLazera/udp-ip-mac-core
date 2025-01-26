`timescale 1ns / 1ps


module ethernet_mac_top_tb;

localparam RGMII_DATA_WIDTH = 4;
localparam FIFO_DATA_WIDTH = 8;

logic clk_125, reset_n;
logic rgmii_phy_rxc;                                   //Recieved ethernet clock signal
logic [RGMII_DATA_WIDTH-1:0] rgmii_phy_rxd;            //Receieved data from PHY
logic rgmii_phy_rxctl;                                 //Control signal (dv ^ er) from PHY
logic rgmii_phy_txc;                                  //Outgoing data clock signal
logic [RGMII_DATA_WIDTH-1:0] rgmii_phy_txd;           //Outgoing ethernet packet data
logic rgmii_phy_txctl;                                //Outgoing control signal (dv ^ er)

logic [FIFO_DATA_WIDTH-1:0] s_tx_axis_tdata;           //Incoming bytes of data from the FIFO    
logic s_tx_axis_tvalid;                                //Indicates FIFO has valid data (is not empty)
logic s_tx_axis_tlast;                                 //Indicates last beat of transaction (final byte in packet)
logic s_tx_axis_trdy;                                //Indicates to FIFO that it can read data (used to set rd_en for FIFIO)
logic [FIFO_DATA_WIDTH-1:0] m_rx_axis_tdata;          //Data to transmit to asynch FIFO
logic m_rx_axis_tvalid;                               //Signal indicating module has data to transmit
logic m_rx_axis_tuser;                                //Used to indicate an error to the FIFO
logic m_rx_axis_tlast;                                //Indicates last byte within a packet
logic s_rx_axis_trdy;                                   //FIFO indicating it is ready for data (not full/empty)

//DUT 
ethernet_mac#(.FIFO_DATA_WIDTH(8), .RGMII_DATA_WIDTH(4)) eth_mac_1(.*);

//125 MHz clock input
always #4 clk_125 = ~clk_125;

initial begin
    clk_125 = 1'b0;
    rgmii_phy_rxc = 1'b0;
    reset_n = 1'b0;
    #50;
    reset_n = 1'b1;
    
    //125MHz Clock Speed
    repeat(80) begin
        #4 rgmii_phy_rxc = ~rgmii_phy_rxc;
    end
    
    //25MHz clock speed
    repeat(80) begin
        #20 rgmii_phy_rxc = ~rgmii_phy_rxc;
    end    
    
    //2.5MHz clock speed
    repeat(80) begin
        #200 rgmii_phy_rxc = ~rgmii_phy_rxc;
    end
    
    $finish;
end


endmodule
