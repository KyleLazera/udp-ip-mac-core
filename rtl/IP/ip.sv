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

 module ip
#(
    parameter AXI_STREAM_WIDTH = 8,
    parameter ETH_FRAME = 1                     // Determines whether the output of this module (on TX Data Path) is
                                                // in the formatting on an ethernet frame (prepended with SRC, DST MAC
                                                // addr & ethernet type) or not
)(
    input wire i_clk,
    input wire i_reset_n,

    /******************************************* TX To Ethernet MAC *************************************/

    /* IP Input - Used for Tx*/
   input wire s_ip_tx_hdr_valid,                                        // Indicates the header inputs are valid
   output wire s_ip_tx_hdr_rdy,                                         // IP tx is ready for next header inputs
   input wire [7:0] s_ip_tx_hdr_type,                                   // Type of Service Field
   input wire [7:0] s_ip_tx_protocol,                                   // L4 protocol (UDP/TCP)
   input wire [31:0] s_ip_tx_src_ip_addr,                               // Source IP address
   input wire [31:0] s_ip_tx_dst_ip_addr,                               // Destination IP address
   input wire [47:0] s_eth_tx_src_mac_addr,                             // Eth source mac address
   input wire [47:0] s_eth_tx_dst_mac_addr,                             // Eth destination mac address   
   input wire [15:0] s_eth_tx_type,                                     // Eth type  

   /* AXI Stream Payload Inputs */
   input wire [AXI_STREAM_WIDTH-1:0] s_tx_axis_tdata,                   // Raw Payload data via AXI Stream
   input wire s_tx_axis_tvalid,                                         // tvalid for payload data 
   input wire s_tx_axis_tlast,                                          // last byte of payload
   output wire s_tx_axis_trdy,                                          // Indicates IP tx is ready for payload data

   /* Output ethernet signals - Needed if ETH_FRAME = 0 */
   input wire m_eth_hdr_trdy,
   output wire m_eth_hdr_tvalid,
   output wire [47:0] m_eth_src_mac_addr,                               //Eth source mac address
   output wire [47:0] m_eth_dst_mac_addr,                               //Eth destination mac address   
   output wire [15:0] m_eth_type,   

   /* Tx Ethernet Frame Output */
   output wire [AXI_STREAM_WIDTH-1:0] m_tx_axis_tdata,                  // Packaged IP data (header & payload)
   output wire m_tx_axis_tvalid,                                        // valid signal for tdata
   output wire m_tx_axis_tlast,                                         // last byte of IP package
   input wire m_tx_axis_trdy,                                           // Back pressure from downstream module indciating it is ready

   /* IP Header fields computed in parallel */
   output wire m_ip_tx_hdr_tvalid,                                      // Indicates the ip total length & checsum fields are valid
   output wire [15:0] m_ip_tx_total_length,
   output wire [15:0] m_ip_tx_checksum,

    /******************************************* RX From Ethernet MAC *************************************/

    /* Ethernet Header Input - Only needed in ETH_FRAME = 0*/
    input wire s_eth_hdr_valid,
    output wire s_eth_hdr_rdy,
    input wire [47:0] s_eth_rx_src_mac_addr,
    input wire [47:0] s_eth_rx_dst_mac_addr,
    input wire [15:0] s_eth_rx_type,

   /* Ethernet Frame Input - Input to eth_rx */
    input wire [AXI_STREAM_WIDTH-1:0] s_rx_axis_tdata,
    input wire s_rx_axis_tvalid,
    input wire s_rx_axis_tlast,
    output wire s_rx_axis_trdy,

    /* De-encapsulated Frame Output */
    input wire m_ip_hdr_trdy,
    output wire m_ip_hdr_tvalid,
    output wire [15:0] m_ip_total_length,
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

wire tx_eth_hdr_rdy;
wire tx_eth_hdr_valid;
wire [47:0] tx_eth_src_mac_addr;
wire [47:0] tx_eth_dst_mac_addr;
wire [15:0] tx_eth_type;

generate
    assign tx_eth_hdr_rdy = (ETH_FRAME) ? 1'b0 : m_eth_hdr_trdy;
    assign m_eth_hdr_tvalid = (ETH_FRAME) ? 1'b0 : tx_eth_hdr_valid;
    assign m_eth_src_mac_addr = (ETH_FRAME) ? 1'b0 : tx_eth_src_mac_addr;
    assign m_eth_dst_mac_addr = (ETH_FRAME) ? 1'b0 : tx_eth_dst_mac_addr;
    assign m_eth_type = (ETH_FRAME) ? 1'b0 : tx_eth_type;
endgenerate

ipv4_tx#(.AXI_STREAM_WIDTH(AXI_STREAM_WIDTH), .ETH_FRAME(ETH_FRAME))
ip_tx(
    .i_clk(i_clk),
    .i_reset_n(i_reset_n),

    /* Input AXI-Stream IP Payload */
    .s_tx_axis_tdata(s_tx_axis_tdata),
    .s_tx_axis_tvalid(s_tx_axis_tvalid),                      
    .s_tx_axis_tlast(s_tx_axis_tlast),                       
    .s_tx_axis_trdy(s_tx_axis_trdy),  

    /* Input IP/Ethernet Header Fields */
    .s_ip_tx_hdr_valid(s_ip_tx_hdr_valid),                     
    .s_ip_tx_hdr_rdy(s_ip_tx_hdr_rdy),                      
    .s_ip_tx_hdr_type(s_ip_tx_hdr_type),                      
    .s_ip_tx_protocol(s_ip_tx_protocol),                
    .s_ip_tx_src_ip_addr(s_ip_tx_src_ip_addr),            
    .s_ip_tx_dst_ip_addr(s_ip_tx_dst_ip_addr),            
    .s_eth_tx_src_mac_addr(s_eth_tx_src_mac_addr),          
    .s_eth_tx_dst_mac_addr(s_eth_tx_dst_mac_addr),          
    .s_eth_tx_type(s_eth_tx_type),  

    /* Outpu AXI-Stream IP packet */
    .m_tx_axis_tdata(m_tx_axis_tdata),
    .m_tx_axis_tvalid(m_tx_axis_tvalid),                     
    .m_tx_axis_tlast(m_tx_axis_tlast),                      
    .m_tx_axis_trdy(m_tx_axis_trdy),  

    /* Total Length & Checksum Calculation */
    .m_ip_tx_hdr_tvalid(m_ip_tx_hdr_tvalid),                                     
    .m_ip_tx_total_length(m_ip_tx_total_length),
    .m_ip_tx_checksum(m_ip_tx_checksum),

    /* Output ethernet header info - Only if ETH_FRAME = 0 */
    .m_eth_hdr_trdy(tx_eth_hdr_rdy),
    .m_eth_hdr_tvalid(tx_eth_hdr_valid),
    .m_eth_src_mac_addr(tx_eth_src_mac_addr),            
    .m_eth_dst_mac_addr(tx_eth_dst_mac_addr),            
    .m_eth_type(tx_eth_type)                     
);


/* RX Data Path */

wire eth_hdr_tvalid;
wire eth_hdr_trdy;
wire [47:0] rx_src_mac_addr;
wire [47:0] rx_dst_mac_addr;
wire [15:0] rx_eth_type;

// If ETH_FRAME is set, drive all the ethernet input signals low
generate 
    assign eth_hdr_tvalid = (ETH_FRAME) ? 1'b0 : s_eth_hdr_valid;
    assign s_eth_hdr_rdy = (ETH_FRAME) ? 1'b0 : eth_hdr_trdy;
    assign rx_src_mac_addr = (ETH_FRAME) ? 1'b0 : s_eth_rx_src_mac_addr;
    assign rx_dst_mac_addr = (ETH_FRAME) ? 1'b0 : s_eth_rx_dst_mac_addr;
    assign rx_eth_type =  (ETH_FRAME) ? 1'b0 : s_eth_rx_type;
endgenerate

ipv4_rx#(.AXI_DATA_WIDTH(AXI_STREAM_WIDTH), .ETH_FRAME(ETH_FRAME))
ip_rx(
    .i_clk(i_clk),
    .i_reset_n(i_reset_n),

    /* Ethernet Input Signals */
    .s_eth_hdr_valid(eth_hdr_tvalid),
    .s_eth_hdr_rdy(eth_hdr_trdy),
    .s_eth_rx_src_mac_addr(rx_src_mac_addr),
    .s_eth_rx_dst_mac_addr(rx_dst_mac_addr),
    .s_eth_rx_type(rx_eth_type),

    /* AXI-Input Signals */
    .s_rx_axis_tdata(s_rx_axis_tdata),
    .s_rx_axis_tvalid(s_rx_axis_tvalid),
    .s_rx_axis_tlast(s_rx_axis_tlast),
    .s_rx_axis_trdy(s_rx_axis_trdy),

    /* Output Signals */
    .m_ip_hdr_trdy(m_ip_hdr_trdy),
    .m_ip_hdr_tvalid(m_ip_hdr_tvalid),
    .m_ip_total_length(m_ip_total_length),
    .m_ip_rx_src_ip_addr(m_ip_rx_src_ip_addr),
    .m_ip_rx_dst_ip_addr(m_ip_rx_dst_ip_addr),
    .m_eth_rx_src_mac_addr(m_eth_rx_src_mac_addr),
    .m_eth_rx_dst_mac_addr(m_eth_rx_dst_mac_addr),
    .m_eth_rx_type(m_eth_rx_type), 
    
    .m_rx_axis_tdata(m_rx_axis_tdata),
    .m_rx_axis_tvalid(m_rx_axis_tvalid),
    .m_rx_axis_tlast(m_rx_axis_tlast),
    .m_rx_axis_trdy(m_rx_axis_trdy),

    /* Status Signals */
    .bad_packet(bad_packet)     
);

 endmodule