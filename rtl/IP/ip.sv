`timescale 1ns / 1ps

/* This is the top-level module for the IP encapsulation/de-encap process. It contains
 * 2 seperate data paths: transmission and reception.
 * Transmission Data Path: IP Payload along with various IP header and ethernet header fields
 * are passed into the module, which then passes the data through ip_tx and ip_eth_tx to form
 * a full frame ready to be transmitted to the ethernet MAC via AXI-Stream.
 * Reception Data Path: Frames are recieved via AXI-Stream and are then de-encapsulated. The header
 * fields for both the IP and Ethernet, specifically, addresses and ethernet type are also 
 * passed out of the module with the payload data.
 */

 //todo: Pull ethernet signals out in parallel for tx

 module ip
#(
    parameter AXI_STREAM_WIDTH = 8
)(
    input wire i_clk,
    input wire i_reset_n,

    /******************************************* TX To Ethernet MAC *************************************/

    /* IP Payload Input - Used for Tx*/
   input wire s_ip_tx_hdr_valid,                                        // Indicates the header inputs are valid
   output wire s_ip_tx_hdr_rdy,                                         // IP tx is ready for next header inputs
   input wire [7:0] s_ip_tx_hdr_type,                                   // Type of Service Field
   input wire [15:0] s_ip_tx_total_length,                              // Total length of payload
   input wire [7:0] s_ip_tx_protocol,                                   // L4 protocol (UDP/TCP)
   input wire [31:0] s_ip_tx_src_ip_addr,                               // Source IP address
   input wire [31:0] s_ip_tx_dst_ip_addr,                               // Destination IP address
   input wire [47:0] s_eth_tx_src_mac_addr,                             //Eth source mac address
   input wire [47:0] s_eth_tx_dst_mac_addr,                             //Eth destination mac address   
   input wire [15:0] s_eth_tx_type,                                     //Eth type  

   /* AXI Stream Payload Inputs */
   input wire [AXI_STREAM_WIDTH-1:0] s_tx_axis_tdata,                   // Raw Payload data via AXI Stream
   input wire s_tx_axis_tvalid,                                         // tvalid for payload data 
   input wire s_tx_axis_tlast,                                          // last byte of payload
   output wire s_tx_axis_trdy,                                          // Indicates IP tx is ready for payload data

   /* Tx Ethernet Frame Output */
   output wire [AXI_STREAM_WIDTH-1:0] m_tx_axis_tdata,                  // Packaged IP data (header & payload)
   output wire m_tx_axis_tvalid,                                        // valid signal for tdata
   output wire m_tx_axis_tlast,                                         // last byte of IP package
   input wire m_tx_axis_trdy,                                           // Back pressure from downstream module indciating it is ready

    /******************************************* RX From Ethernet MAC *************************************/

   /* Ethernet Frame Input - Input to eth_rx */
    input wire [AXI_STREAM_WIDTH-1:0] s_rx_axis_tdata,
    input wire s_rx_axis_tvalid,
    input wire s_rx_axis_tlast,
    output wire s_rx_axis_trdy,

    /* De-encapsulated Frame Output */
    input wire m_ip_hdr_trdy,
    output wire m_ip_hdr_tvalid,
    output wire [31:0] m_ip_rx_src_ip_addr,
    output wire [31:0] m_ip_rx_dst_ip_addr,
    output wire [47:0] m_eth_rx_src_mac_addr,
    output wire [47:0] m_eth_rx_dst_mac_addr,
    output wire [15:0] m_eth_rx_type,    

    /* IP Frame Payload */
    output wire [AXI_STREAM_WIDTH-1:0] m_rx_axis_tdata,
    output wire m_rx_axis_tvalid,
    output wire m_rx_axis_tlast,
    input wire m_rx_axis_trdy,

    /* Status Flags */
    output wire bad_packet     
);

/* TX Data Path */

ipv4_tx#(.AXI_STREAM_WIDTH(AXI_STREAM_WIDTH))
ip_tx(
    .i_clk(i_clk),
    .i_reset_n(i_reset_n),
    .s_tx_axis_tdata(s_tx_axis_tdata),
    .s_tx_axis_tvalid(s_tx_axis_tvalid),                      
    .s_tx_axis_tlast(s_tx_axis_tlast),                       
    .s_tx_axis_trdy(s_tx_axis_trdy),                       
    .s_ip_tx_hdr_valid(s_ip_tx_hdr_valid),                     
    .s_ip_tx_hdr_rdy(s_ip_tx_hdr_rdy),                      
    .s_ip_tx_hdr_type(s_ip_tx_hdr_type),                
    .s_ip_tx_total_length(s_ip_tx_total_length),           
    .s_ip_tx_protocol(s_ip_tx_protocol),                
    .s_ip_tx_src_ip_addr(s_ip_tx_src_ip_addr),            
    .s_ip_tx_dst_ip_addr(s_ip_tx_dst_ip_addr),            
    .s_eth_tx_src_mac_addr(s_eth_tx_src_mac_addr),          
    .s_eth_tx_dst_mac_addr(s_eth_tx_dst_mac_addr),          
    .s_eth_tx_type(s_eth_tx_type),  

    .m_tx_axis_tdata(m_tx_axis_tdata),
    .m_tx_axis_tvalid(m_tx_axis_tvalid),                     
    .m_tx_axis_tlast(m_tx_axis_tlast),                      
    .m_tx_axis_trdy(m_tx_axis_trdy),                        
    .m_eth_hdr_trdy(),
    .m_eth_hdr_tvalid(),
    .m_eth_src_mac_addr(),            
    .m_eth_dst_mac_addr(),            
    .m_eth_type()                     
);


/* RX Data Path */

wire [AXI_STREAM_WIDTH-1:0] rx_axis_tdata;
wire rx_axis_tvalid;
wire rx_axis_tlast;
wire rx_axis_trdy;

wire rx_eth_hdr_trdy;
wire rx_eth_hdr_tvalid;
wire [47:0] rx_eth_src_mac_addr;
wire [47:0] rx_eth_dst_mac_addr;
wire [15:0] rx_eth_type;

ipv4_rx#(.AXI_STREAM_WIDTH(AXI_STREAM_WIDTH))
ip_rx(
    .i_clk(i_clk),
    .i_reset_n(i_reset_n),
    .s_eth_hdr_valid(rx_eth_hdr_tvalid),
    .s_eth_hdr_rdy(rx_eth_hdr_trdy),
    .s_eth_rx_src_mac_addr(rx_eth_src_mac_addr),
    .s_eth_rx_dst_mac_addr(rx_eth_dst_mac_addr),
    .s_eth_rx_type(rx_eth_type),
    .s_rx_axis_tdata(rx_axis_tdata),
    .s_rx_axis_tvalid(rx_axis_tvalid),
    .s_rx_axis_tlast(rx_axis_tlast),
    .s_rx_axis_trdy(rx_axis_trdy),
    .m_ip_hdr_trdy(m_ip_hdr_trdy),
    .m_ip_hdr_tvalid(m_ip_hdr_tvalid),
    .m_ip_rx_src_ip_addr(m_ip_rx_src_ip_addr),
    .m_ip_rx_dst_ip_addr(m_ip_rx_dst_ip_addr),
    .m_eth_rx_src_mac_addr(m_eth_rx_src_mac_addr),
    .m_eth_rx_dst_mac_addr(m_eth_rx_dst_mac_addr),
    .m_eth_rx_type(m_eth_rx_type), 
    .m_rx_axis_tdata(m_rx_axis_tdata),
    .m_rx_axis_tvalid(m_rx_axis_tvalid),
    .m_rx_axis_tlast(m_rx_axis_tlast),
    .m_rx_axis_trdy(m_rx_axis_trdy),
    .bad_packet(bad_packet)     
);

 endmodule