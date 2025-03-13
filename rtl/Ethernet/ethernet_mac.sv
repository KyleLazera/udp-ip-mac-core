`timescale 1ns / 1ps

/* 
 * This module connects the tx mac, rx mac and rgmii interface and adds custom logic used to determine the link speed of
 * the ethernet line.
*/

module ethernet_mac
#(
    parameter FIFO_DATA_WIDTH = 8,
    parameter RGMII_DATA_WIDTH = 4
)
(
    input wire clk_125,
    input wire clk90_125,
    input wire reset_n,

    /* External PHY Interface Signals */
    input wire rgmii_phy_rxc,                                   //Recieved ethernet clock signal
    input wire [RGMII_DATA_WIDTH-1:0] rgmii_phy_rxd,            //Receieved data from PHY
    input wire rgmii_phy_rxctl,                                 //Control signal (dv ^ er) from PHY
    output wire rgmii_phy_txc,                                  //Outgoing data clock signal
    output wire [RGMII_DATA_WIDTH-1:0] rgmii_phy_txd,           //Outgoing ethernet packet data
    output wire rgmii_phy_txctl,                                //Outgoing control signal (dv ^ er)

    /* TX FIFO Interface */
    input wire [FIFO_DATA_WIDTH-1:0] s_tx_axis_tdata,           //Incoming bytes of data from the FIFO    
    input wire s_tx_axis_tvalid,                                //Indicates FIFO has valid data (is not empty)
    input wire s_tx_axis_tlast,                                 //Indicates last beat of transaction (final byte in packet)
    output wire s_tx_axis_trdy,                                 //Indicates to FIFO that it can read data (used to set rd_en for FIFIO)

    /* RX FIFO Interface */
    output wire rgmii_rxc,                                      //RX clock from rgmii used to drive data to rx fifo
    output wire [FIFO_DATA_WIDTH-1:0] m_rx_axis_tdata,          //Data to transmit to asynch FIFO
    output wire m_rx_axis_tvalid,                               //Signal indicating module has data to transmit
    output wire m_rx_axis_tuser,                                //Used to indicate an error to the FIFO
    output wire m_rx_axis_tlast,                                //Indicates last byte within a packet
    input wire s_rx_axis_trdy,                                  //FIFO indicating it is ready for data (not full/empty)

    /* Control Signals(s) */
    output wire mii_mode                                        //Indicates whether we are operating in mii (10/100 mbps) or 1gbps

);


/****************************************************************
 * Logic to determine the linkspeed of the rgmii recieved clock
*****************************************************************/

reg [2:0] rgmii_rxc_cntr = 4'h0;
reg [2:0] rgmii_rxc_rt = 4'h0;                  
reg [1:0] rxc_edge_cntr = 1'b0;
reg [6:0] rxc_ref_cntr = 7'h0;
reg [1:0] link_speed_reg = 2'b10;
wire [1:0] link_speed;
wire mii_sel;

/* Logic to re-time the rgmii recieved clock */
always @(posedge rgmii_phy_rxc) begin  
    rgmii_rxc_cntr <= rgmii_rxc_cntr + 1;                     
end

/* Logic to determine the link speed */
always @(posedge clk_125) begin
    if(!reset_n) begin
        rxc_ref_cntr <= 7'h0; 
        link_speed_reg <= 2'b10;   
        rxc_edge_cntr <= 3'h0;   
    end else begin
        rxc_ref_cntr <= rxc_ref_cntr + 1;

        rgmii_rxc_rt <= {rgmii_rxc_rt[1:0], rgmii_rxc_cntr[2]};

        //Count the number of falling and rising edges of re-timed rxc
        if(rgmii_rxc_rt[1] ^ rgmii_rxc_rt[0])
            rxc_edge_cntr <= rxc_edge_cntr + 1;

        //If the reference counter reached its maximum value - this indicates 2.5MHz clock speed
        if(&rxc_ref_cntr == 1) begin
            rxc_edge_cntr <= 3'h0;
            link_speed_reg <= 2'b00;
        end

        /*If we have found 3 edges on the re-timed rxc - this indicates a full period has been completed
             ____      ____
        ____|    |____|    |____   <- A period constitues the first rising edge, the falling edge and the next rising edge 

        The order of the edges can also be flipped - falling edge, rising edge, falling edge - and this still constitues a full period. 
        */
        if(rxc_edge_cntr == 3'h3) begin
            rxc_ref_cntr <= 7'd0;
            rxc_edge_cntr <= 3'h0;                        

            //25MHz Clock Speed - If reference clock is greater than 48
            if(rxc_ref_cntr[5:4]) 
                link_speed_reg <= 2'b01;
            //125 MHz Clock Speed
            else  
                link_speed_reg <= 2'b10;

        end
    end
end

/* Output Logic */
assign link_speed = link_speed_reg;
assign mii_sel = (link_speed != 2'b10);

////////////////////////////////////////////////////////////////////////
// The link speed value (driven in the 125MHz clock domain) is used
// to drive data into the rx MAC (operating in the rxc domain), therefore, 
// to avoid a possibly metastable signal being passed, we have to resynchronize
// the link speed value into teh rxc domain.
/////////////////////////////////////////////////////////////////////////////

wire [1:0] link_speed_rxc_sync;

cdc_signal_sync#(.PIPELINE(0)) link_speed_sync_0(
    .i_dst_clk(rgmii_phy_rxc),
    .i_signal(link_speed[0]),
    .o_signal_sync(link_speed_rxc_sync[0]),
    .o_pulse_sync()
);

cdc_signal_sync#(.PIPELINE(0)) link_speed_sync_1(
    .i_dst_clk(rgmii_phy_rxc),
    .i_signal(link_speed[1]),
    .o_signal_sync(link_speed_rxc_sync[1]),
    .o_pulse_sync()
);

/**********************************************************
 * Module Instantiations & Intermediary Signals 
***********************************************************/

/* Intermediary Signals :
 * The signal names have the following format to improve readability
 * Source_Destination_TransmissionDirection_DataType
*/
wire [FIFO_DATA_WIDTH-1:0] mac_rgmii_tx_data;
wire mac_rgmii_tx_dv;
wire mac_rgmii_tx_er;
wire rgmii_mac_tx_rdy;
wire rgmii_mac_rx_clk;
wire [FIFO_DATA_WIDTH-1:0] rgmii_mac_rx_data;
wire rgmii_mac_rx_dv;
wire rgmii_mac_rx_er;
wire rgmii_mac_rx_rdy;

//RGMII PHY 
rgmii_phy_if rgmii_phy
(
    .clk_125(clk_125),
    .clk90_125(clk90_125),
    .reset_n(reset_n),

    // PHY Interface - external connections 
    .rgmii_phy_rxc(rgmii_phy_rxc),
    .rgmii_phy_rxd(rgmii_phy_rxd),
    .rgmii_phy_rxctl(rgmii_phy_rxctl),
    .rgmii_phy_txc(rgmii_phy_txc),
    .rgmii_phy_txd(rgmii_phy_txd),
    .rgmii_phy_txctl(rgmii_phy_txctl),

    // MAC Interface 
    .rgmii_mac_tx_data(mac_rgmii_tx_data),       
    .rgmii_mac_tx_dv(mac_rgmii_tx_dv),                   
    .rgmii_mac_tx_er(mac_rgmii_tx_er),              
    .rgmii_mac_tx_rdy(rgmii_mac_tx_rdy),             
    .rgmii_mac_rx_clk(rgmii_mac_rx_clk),             
    .rgmii_mac_rx_data(rgmii_mac_rx_data),      
    .rgmii_mac_rx_dv(rgmii_mac_rx_dv),              
    .rgmii_mac_rx_er(rgmii_mac_rx_er), 
    .rgmii_mac_rx_rdy(rgmii_mac_rx_rdy),             
   
    // Control Signal(s)
    .link_speed(link_speed_rxc_sync)  //link_speed            
);

//TX MAC
tx_mac 
#(
    .DATA_WIDTH(8)
) tx_mac_module
(
    .clk(clk_125),                                 
    .reset_n(reset_n),                             
                                                
    // AXI Stream Input - FIFO                 
    .s_tx_axis_tdata(s_tx_axis_tdata),    
    .s_tx_axis_tvalid(s_tx_axis_tvalid),                    
    .s_tx_axis_tlast(s_tx_axis_tlast),                     
    .s_tx_axis_tkeep(),                     
    .s_tx_axis_tuser(),                     
                                                
    // AXI Stream Output - FIFO                   
    .s_tx_axis_trdy(s_tx_axis_trdy),                     
                                                
    // RGMII Interface                           
    .rgmii_mac_tx_rdy(rgmii_mac_tx_rdy),                    
    .rgmii_mac_tx_data(mac_rgmii_tx_data), 
    .rgmii_mac_tx_dv(mac_rgmii_tx_dv),                    
    .rgmii_mac_tx_er(mac_rgmii_tx_er),                    
                                                
    // Control signals(s)                            
    .mii_select(mii_sel),
    .link_speed(link_speed)                          
);

//RX MAC
rx_mac 
#(
    .DATA_WIDTH(8)
)
rx_mac_module
(
    .clk(rgmii_mac_rx_clk),                               
    .reset_n(reset_n),                           
                                              
    // AXI Stream Output - FIFO                 
    .m_rx_axis_tdata(m_rx_axis_tdata), 
    .m_rx_axis_tvalid(m_rx_axis_tvalid),                 
    .m_rx_axis_tuser(m_rx_axis_tuser),                  
    .m_rx_axis_tlast(m_rx_axis_tlast),                  
                                              
    // FIFO Input/Control Signals              
    .s_rx_axis_trdy(s_rx_axis_trdy),                    
                                              
    // RGMII Interface                          
    .rgmii_mac_rx_data(rgmii_mac_rx_data),
    .rgmii_mac_rx_dv(rgmii_mac_rx_dv),                   
    .rgmii_mac_rx_er(rgmii_mac_rx_er),
    .rgmii_mac_rx_rdy(rgmii_mac_rx_rdy)                 
); 

assign rgmii_rxc = rgmii_mac_rx_clk;
assign mii_mode = mii_sel;

endmodule