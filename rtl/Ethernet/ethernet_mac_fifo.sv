`timescale 1ns / 1ps

/* Top level module for ethernet mac that contains writable and readable FIFO's */

module ethernet_mac_fifo
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
    output wire m_tx_axis_trdy,                                 //Indicates the tx FIFO is not almost full/has space to store data

    /* Rx FIFO - AXI Interface*/
    output wire [AXI_DATA_WIDTH-1:0] m_rx_axis_tdata,            //Rx data receieved from ethernet MAC   
    output wire m_rx_axis_tvalid,                                //Indicates rx FIFO is not empty and has data 
    output wire m_rx_axis_tlast,                                 //Indicates last beat of transaction (final byte in packet)
    input wire s_rx_axis_trdy                                    //Acts as a read enable signal to rx fifo   
);

localparam FIFO_DATA_WIDTH = 9;
localparam AXI_DATA_WIDTH = 8;
localparam RGMII_DATA_WIDTH = 4;
localparam RX_FIFO_DEPTH = 8192;
localparam TX_FIFO_DEPTH = 4096;

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
wire tx_mac_trdy;
wire mii_mode;
reg tx_fifo_rd_en;

assign tx_fifo_not_full = ~tx_fifo_full;  
assign tx_fifo_not_empty = ~tx_fifo_empty;
assign tx_fifo_rd_en = (mii_mode) ? tx_mac_trdy : (tx_mac_trdy & !tx_fifo_data_out[0]);

/* RX FIFO */
wire rx_clk;
wire [AXI_DATA_WIDTH-1:0] rx_mac_data;
wire rx_mac_last;
wire rx_mac_data_valid;
wire rx_mac_tuser_error;

wire rx_fifo_full;
wire rx_fifo_almost_full;
wire rx_fifo_empty;
wire rx_fifo_almost_empty;
wire rx_fifo_not_full;
wire rx_fifo_not_empty;

assign rx_fifo_not_full = ~rx_fifo_full;
assign rx_fifo_not_empty = ~rx_fifo_empty; 

/****************************************************************
Output Logic
*****************************************************************/

assign m_tx_axis_trdy = tx_fifo_not_full;
assign m_rx_axis_tvalid = (rx_pckt_cntr > 0);

//////////////////////////////////////////////////////////////////////////////////////
// Handshaking Logic - Ensures 1Gb/s throughput by preventing the TX FIFO from emptying 
// mid-packet. The TX MAC reads data at 125MHz, while the system writes at 100MHz. To 
// prevent the MAC from catching up and starving the FIFO, additional handshaking logic 
// ensures the TX MAC only starts reading when a full packet is available.
//////////////////////////////////////////////////////////////////////////////////////

reg [8:0] tx_pckt_cntr = 9'b0;
reg [2:0] tx_pkt_boundary_resync = 3'b0;
wire tx_pkt_boundary;          //tlast from write fifo domain 

wire increment_tx_cntr;
wire decrement_tx_cntr;

assign decrement_tx_cntr = tx_fifo_data_out[0] & tx_mac_trdy;

// Only identify a true tlast when tvalid and trdy are also high 
assign tx_pkt_boundary = s_tx_axis_tlast & s_tx_axis_tvalid & m_tx_axis_trdy;

always @(posedge clk_125) begin
    if(!i_reset_n)
        tx_pckt_cntr <= 1'b0;
    else begin
        //Rising edge detection of packet boundary signal (tlast from write tx fifo domain)
        if(increment_tx_cntr & !decrement_tx_cntr)
            tx_pckt_cntr <= tx_pckt_cntr + 1;
        //tlast detection from read FIFO domain
        else if(decrement_tx_cntr & !increment_tx_cntr)
            tx_pckt_cntr <= tx_pckt_cntr - 1;

    end
end

cdc_signal_sync #(.PIPELINE(1)) tx_pckt_boundry_sync (
    .i_dst_clk(clk_125),
    .i_signal(tx_pkt_boundary),
    .o_signal_sync(),
    .o_pulse_sync(increment_tx_cntr)
);

//////////////////////////////////////////////////////////////////////////////////////
// Handshaking Logic - Similarly to the tx handshaking logic, we also want to make sure 
// that the slave (user) only reads data from the rx fifo when there is AT LEAST a full
// packet present in the FIFO. The reason for this is because if the user could
// read the bytes as they were ready, the onus would be on the user to drop any bad packets.
// By making teh user wait until full packets are availbale, erronous packets can
// easily be dropped by the rx MAC, and teh user will not have to handle this.
//////////////////////////////////////////////////////////////////////////////////////

reg [8:0] rx_pckt_cntr = 9'b0;
reg [2:0] rx_pkt_boundary_resync = 3'b0;
reg [1:0] rx_tuser_resync = 2'b0;
wire rx_pkt_boundary; 

wire increment_rx_cntr;
wire decrement_rx_cntr;

assign increment_rx_cntr = tlast_pulse_crossed & !tuser_pulse_crossed;
assign decrement_rx_cntr = m_rx_axis_tlast & m_rx_axis_tvalid; //& s_rx_axis_trdy

// Only identify a true tlast when tvalid and trdy are also high 
assign rx_pkt_boundary = rx_mac_last & rx_mac_data_valid & rx_fifo_not_full;

always @(posedge i_clk) begin
    if(!i_reset_n)
        rx_pckt_cntr <= 1'b0;
    else begin
        
        //////////////////////////////////////////////////////////////////////////////////////////////////////////
        // It is important to specify that the counter will only be incremented when the increment signal is true
        // and the decrement signal is false. Similarly, the same is true when decrementing the counter. The reason
        // for this is there may be a scenario where the increment condition and decrement condition are true 
        // at the same time. In this case, the counter should not change value (1 - 1 = 0), therefore, by 
        // checking both conditions we avoid this scenario.
        //////////////////////////////////////////////////////////////////////////////////////////////////////////

        if(increment_rx_cntr & !decrement_rx_cntr)
            rx_pckt_cntr <= rx_pckt_cntr + 1;
        
        else if(decrement_rx_cntr & !increment_rx_cntr)
            rx_pckt_cntr <= rx_pckt_cntr - 1;
        
    end
end

///////////////////////////////////////////////////////////////////////////////////
// To succesfully use the tlast and tuser signals from the rx mac, they must be 
// crossed from the 125MHz domain into the 100MHz clock domain. The following module
// instantiations implement the cdc logic to cross a pulse along with feedback from
// a faster domain into a slower domain.
///////////////////////////////////////////////////////////////////////////////////

wire tlast_pulse_crossed;
wire tuser_pulse_crossed;

cdc_pulse_stretch rx_tlast_pulse_detection
(
    .i_src_clk(clk_125),
    .i_dst_clk(i_clk),
    .i_pulse(rx_pkt_boundary),
    .o_pulse(tlast_pulse_crossed)
);

cdc_pulse_stretch rx_tuser_pulse_detection
(
    .i_src_clk(clk_125),
    .i_dst_clk(i_clk),
    .i_pulse(rx_mac_tuser_error),
    .o_pulse(tuser_pulse_crossed)
);

/****************************************************************
Ethernet MAC Instantiation
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
    .s_tx_axis_tvalid(tx_pckt_cntr > 0),
    .s_tx_axis_tlast(tx_fifo_data_out[0]),
    .s_tx_axis_trdy(tx_mac_trdy),
    //RX FIFIO - AXI Interface
    .rgmii_rxc(rx_clk),
    .m_rx_axis_tdata(rx_mac_data),
    .m_rx_axis_tvalid(rx_mac_data_valid),
    .m_rx_axis_tuser(rx_mac_tuser_error),
    .m_rx_axis_tlast(rx_mac_last),
    .s_rx_axis_trdy(rx_fifo_not_full),
    //Control Signal(s)
    .mii_mode(mii_mode)
    );

/****************************************************************
TX FIFO Instantiation
*****************************************************************/

fifo#(
    .FWFT(1),
    .DATA_WIDTH(FIFO_DATA_WIDTH),
    .FIFO_DEPTH(TX_FIFO_DEPTH)
) tx_fifo (
    .clk_wr(i_clk), 
    .clk_rd(clk_125),
    .reset_n(i_reset_n),
    .data_in({s_tx_axis_tdata, s_tx_axis_tlast}),
    .write_en(s_tx_axis_tvalid & m_tx_axis_trdy),
    .data_out(tx_fifo_data_out),
    .read_en(tx_fifo_rd_en & tx_fifo_not_empty), 
    .empty(tx_fifo_empty),
    .almost_empty(tx_fifo_almost_empty),
    .full(tx_fifo_full),
    .almost_full(tx_fifo_almost_full),
    //Not needed for TX MAC - tie down to 0
    .drop_pckt(1'b0),
    .latch_addr(1'b0)
);

/****************************************************************
RX FIFO Instantiation
*****************************************************************/

fifo#(
    .FWFT(1),
    .DATA_WIDTH(FIFO_DATA_WIDTH),
    .FIFO_DEPTH(RX_FIFO_DEPTH)
) rx_fifo (
    .clk_wr(rx_clk),
    .clk_rd(i_clk),
    .reset_n(i_reset_n),
    .data_in({rx_mac_data, rx_mac_last}),
    .write_en(rx_mac_data_valid & rx_fifo_not_full),
    .data_out({m_rx_axis_tdata, m_rx_axis_tlast}),
    .read_en(s_rx_axis_trdy & m_rx_axis_tvalid),
    .empty(rx_fifo_empty),
    .almost_empty(rx_fifo_almost_empty),
    .full(rx_fifo_full),
    .almost_full(rx_fifo_almost_full),
    .drop_pckt(rx_mac_tuser_error),  
    .latch_addr(rx_mac_last & !rx_mac_tuser_error)
);

endmodule : ethernet_mac_fifo

