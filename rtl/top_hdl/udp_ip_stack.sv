
module udp_ip_stack
#(
    parameter UDP_CHECKSUM = 1,
    parameter MAX_PAYLOAD = 1472,
    parameter ETH_FRAME = 1,
    parameter AXI_DATA_WIDTH = 8
)
(
    input wire i_clk,
    input wire i_reset_n, 

    /******************************************* TX To Ethernet MAC *************************************/

    // IP Header Inputs
    input wire s_tx_hdr_valid,                                           // Indicates the header inputs are valid
    output wire s_tx_hdr_rdy,                                            // UDP/IP stack is ready for UDP/IP/Ethernet header fields
    input wire [7:0] s_ip_tx_hdr_type,                                   // Type of Service Field
    input wire [15:0] s_ip_tx_total_length,                              // Total length of payload
    input wire [7:0] s_ip_tx_protocol,                                   // L4 protocol (UDP/TCP)
    input wire [31:0] s_ip_tx_src_ip_addr,                               // Source IP address
    input wire [31:0] s_ip_tx_dst_ip_addr,                               // Destination IP address 
    
    // Ethernet Header Inputs
    input wire [47:0] s_eth_tx_src_mac_addr,                             // Eth source mac address
    input wire [47:0] s_eth_tx_dst_mac_addr,                             // Eth destination mac address   
    input wire [15:0] s_eth_tx_type,                                     // Eth type 

    // UDP Header Inputs
    input wire [15:0] s_udp_tx_src_port,                                // Source Port
    input wire [15:0] s_udp_tx_dst_port,                                // Destination Port

    // AXI-Stream Payload Input
    input wire [AXI_DATA_WIDTH-1:0] s_tx_axis_tdata,                    // Input Data payload - passed in byte-wise
    input wire s_tx_axis_tvalid,                                        // Indicates input byte is valid
    input wire s_tx_axis_tlast,                                         // Indicates last byte within the stream
    output wire s_tx_axis_trdy,                                         // Downstream module indicates it is ready for data

    // UDP Header fields - computed in parallel
    output wire m_udp_ip_hdr_valid,
    output wire [15:0] m_udp_tx_length,
    output wire [15:0] m_udp_tx_checksum,
    output wire [15:0] m_ip_tx_total_length,
    output wire [15:0] m_ip_tx_checksum,

    // AXI-Stream Payload Output
    output wire [AXI_DATA_WIDTH-1:0] m_tx_axis_tdata,
    output wire m_tx_axis_tvalid,
    output wire m_tx_axis_tlast,
    input wire m_tx_axis_trdy,

    /******************************************* RX To Ethernet MAC *************************************/

    /////////////////////////////////////////////////////////////////////////////
    // Ethernet Header Input. These fields are only needed is ETH_FRAME = 0, 
    // indicating that the payload being passed from the ethernet MAC does not
    // have the ethernet source & destination MAC address + the ethernet type.
    // In that case, these values are passed through in-parallel.
    /////////////////////////////////////////////////////////////////////////////
    
    input wire s_rx_hdr_tvalid,                                         // Indicates the input ethernet fields are valid                         
    output wire s_rx_hdr_trdy,                                          // Indicates the IP module is ready to recieve ethernet fields
    input wire [47:0] s_eth_rx_src_mac_addr,                            // Ethernet Source MAC address
    input wire [47:0] s_eth_rx_dst_mac_addr,                            // Ethernet Destination MAC address
    input wire [15:0] s_eth_rx_type,                                    // Ethernet Type

   // Ethernet Payload Input
    input wire [AXI_STREAM_WIDTH-1:0] s_rx_axis_tdata,                  // Byte streamed data 
    input wire s_rx_axis_tvalid,                                        // Flag indiciating is byte streamed data is valid
    input wire s_rx_axis_tlast,                                         // Flag indicating last byte within a packet
    output wire s_rx_axis_trdy,                                         // Signals to ethernet MAc that IP-UDP stack are ready to recieve data

    // IP Header Fields Output
    input wire m_ip_hdr_trdy,                                           // Passed into ip/udp stack to indicate the up-stream module is ready for data
    output wire m_ip_hdr_tvalid,                                        // Indicates the header data is valid
    output wire [15:0] m_ip_total_length,                               // IP packet total length field
    output wire [31:0] m_ip_rx_src_ip_addr,                             // Source IP address
    output wire [31:0] m_ip_rx_dst_ip_addr,                             // Destination IP address
    
    // Ethernet Output fields
    output wire [47:0] m_eth_rx_src_mac_addr,                           // Source MAC address
    output wire [47:0] m_eth_rx_dst_mac_addr,                           // Destination MAC Address
    output wire [15:0] m_eth_rx_type,                                   // Ethernet type

    // UDP Header Fields Output 
    input wire s_udp_rx_hdr_trdy,                                       // Up-stream module is ready for UDP header data
    output wire s_udp_rx_hdr_tvalid,                                    // UDP header data is valid
    output wire [15:0] s_udp_rx_src_port,                               // UDP source Port
    output wire [15:0] s_udp_rx_dst_port,                               // UDP Destination port
    output wire [15:0] s_udp_rx_length_port,                            // UDP Length
    output wire [15:0] s_udp_rx_hdr_checksum,                           // UDP checksum

    // IP Header Fields Output
    input wire m_ip_hdr_trdy,                                           // Up-Stream module is ready for IP header data
    output wire m_ip_hdr_tvalid,                                        // IP Header data is valid
    output wire [15:0] m_ip_total_length,                               // Total length of IP packet
    output wire [31:0] m_ip_rx_src_ip_addr,                             // Source IP address
    output wire [31:0] m_ip_rx_dst_ip_addr,                             // Destination IP address

    // Raw Payload Output
    output wire [AXI_STREAM_WIDTH-1:0] m_rx_axis_tdata,                 // Byte streamed payload
    output wire m_rx_axis_tvalid,                                       // Payload is valid
    output wire m_rx_axis_tlast,                                        // Last byte in payload
    input wire m_rx_axis_trdy                                           // Up-stream module is ready for data from master
);

/* Data Path Registers */

wire ip_hdr_valid;
wire udp_hdr_valid;

wire s_udp_hdr_trdy;
wire s_ip_hdr_trdy;

wire [AXI_DATA_WIDTH-1:0] udp_tx_axis_tdata;
wire udp_tx_axis_tvalid;
wire udp_tx_axis_tlast;
wire udp_tx_axis_trdy;

wire [AXI_DATA_WIDTH-1:0] ip_rx_axis_data;
wire ip_rx_axis_tvalid;
wire ip_rx_axis_tlast;
wire ip_rx_axis_trdy;


/* UDP Module */

udp#(.AXI_DATA_WIDTH(AXI_DATA_WIDTH),
     .UDP_CHECKSUM(UDP_CHECKSUM),
     .MAX_PAYLOAD(MAX_PAYLOAD)
) udp_stack (

    .i_clk(i_clk),
    .i_reset_n(i_reset_n),
    
    /*********** TX Data Path ***********/

    // UDP Field Inputs
    .s_udp_tx_hdr_trdy(s_udp_hdr_trdy),
    .s_udp_tx_hdr_tvalid(s_tx_hdr_valid),
    .s_udp_tx_src_port(s_udp_tx_src_port),
    .s_udp_tx_dst_port(s_udp_tx_dst_port),

    //IP Field Inputs
    .s_ip_tx_src_ip_addr(s_ip_tx_src_ip_addr),                               
    .s_ip_tx_dst_ip_addr(s_ip_tx_dst_ip_addr), 
    .s_ip_tx_protocol(s_ip_tx_protocol),  

    // AXI-Stream Payload
    .s_tx_axis_tdata(s_tx_axis_tdata),
    .s_tx_axis_tvalid(s_tx_axis_tvalid),
    .s_tx_axis_tlast(s_tx_axis_tlast),
    .s_tx_axis_trdy(s_tx_axis_trdy),

    // TX Data Path Output
    .m_udp_tx_hdr_valid(udp_hdr_valid),
    .m_udp_tx_length(m_udp_tx_length),
    .m_udp_tx_checksum(m_udp_tx_checksum),

    // UDP Packet Output
    .m_tx_axis_tdata(udp_tx_axis_tdata),
    .m_tx_axis_tvalid(udp_tx_axis_tvalid),
    .m_tx_axis_tlast(udp_tx_axis_tlast),
    .m_tx_axis_trdy(udp_tx_axis_trdy),

    /*********** RX Data Path ***********/
    
    .s_rx_axis_tdata(ip_rx_axis_data),
    .s_rx_axis_tvalid(ip_rx_axis_tvalid),
    .s_rx_axis_tlast(ip_rx_axis_tlast),
    .s_rx_axis_trdy(ip_rx_axis_trdy),

    .m_rx_axis_tdata(m_rx_axis_tdata),
    .m_rx_axis_tvalid(m_rx_axis_tvalid),
    .m_rx_axis_tlast(m_rx_axis_tlast),
    .m_rx_axis_trdy(m_rx_axis_trdy),

    .s_udp_rx_hdr_trdy(s_udp_rx_hdr_trdy),
    .s_udp_rx_hdr_tvalid(s_udp_rx_hdr_tvalid),
    .s_udp_rx_src_port(s_udp_rx_src_port),
    .s_udp_rx_dst_port(s_udp_rx_dst_port),
    .s_udp_rx_length_port(s_udp_rx_length_port),
    .s_udp_rx_hdr_checksum(s_udp_rx_hdr_checksum)
);


/* IP Module */

ip#(.AXI_STREAM_WIDTH(AXI_DATA_WIDTH),
    .ETH_FRAME(ETH_FRAME)
) ip_stack (

    .i_clk(i_clk),
    .i_reset_n(i_reset_n),

    /*********** TX Data Path ***********/

    // IP Header Input
   .s_ip_tx_hdr_valid(s_tx_hdr_valid),                                        
   .s_ip_tx_hdr_rdy(s_ip_hdr_trdy),                                
   .s_ip_tx_hdr_type(s_ip_tx_hdr_type),                                                          
   .s_ip_tx_protocol(s_ip_tx_protocol),                                
   .s_ip_tx_src_ip_addr(s_ip_tx_src_ip_addr),                             
   .s_ip_tx_dst_ip_addr(s_ip_tx_dst_ip_addr),                             
   .s_eth_tx_src_mac_addr(s_eth_tx_src_mac_addr),                          
   .s_eth_tx_dst_mac_addr(s_eth_tx_dst_mac_addr),                             
   .s_eth_tx_type(s_eth_tx_type),                                     

   // AXI Stream Payload Inputs 
   .s_tx_axis_tdata(udp_tx_axis_tdata),                   
   .s_tx_axis_tvalid(udp_tx_axis_tlast),                                        
   .s_tx_axis_tlast(udp_tx_axis_tlast),                                          
   .s_tx_axis_trdy(udp_tx_axis_trdy),                                    

   // Output ethernet signals - Not needed because ETH_FRAME = 1, therefore the output AXI-Stream
   // payload will have teh ethernet frame data incorporated into it.
   m_eth_hdr_trdy(),
   m_eth_hdr_tvalid(),
   m_eth_src_mac_addr(),                               
   m_eth_dst_mac_addr(),                                
   m_eth_type(),   

   // IP Header fields computed in parallel 
   .m_ip_tx_hdr_tvalid(ip_hdr_valid),                                     
   .m_ip_tx_total_length(m_ip_tx_total_length),
   .m_ip_tx_checksum(m_ip_tx_checksum),

   // Tx Ethernet Frame Output 
   .m_tx_axis_tdata(m_tx_axis_tdata),                 
   .m_tx_axis_tvalid(m_tx_axis_tvalid),                                       
   .m_tx_axis_tlast(m_tx_axis_tlast),                                         
   .m_tx_axis_trdy(m_tx_axis_trdy),                                          

    /*********** RX Data Path ***********/

    // Ethernet Header Input - Only needed in ETH_FRAME = 0
    .s_eth_hdr_valid(),
    .s_eth_hdr_rdy(),
    .s_eth_rx_src_mac_addr(),
    .s_eth_rx_dst_mac_addr(),
    .s_eth_rx_type(),

    // Ethernet Frame Input - Input to eth_rx 
    .s_rx_axis_tdata(s_rx_axis_tdata),
    .s_rx_axis_tvalid(s_rx_axis_tvalid),
    .s_rx_axis_tlast(s_rx_axis_tlast),
    .s_rx_axis_trdy(s_rx_axis_trdy),

    // De-encapsulated IP Frame Output 
    .m_ip_hdr_trdy(m_ip_hdr_trdy),
    .m_ip_hdr_tvalid(m_ip_hdr_tvalid),
    .m_ip_total_length(m_ip_total_length),
    .m_ip_rx_src_ip_addr(m_ip_rx_src_ip_addr),
    .m_ip_rx_dst_ip_addr(m_ip_rx_dst_ip_addr),
    .m_eth_rx_src_mac_addr(m_eth_rx_src_mac_addr),
    .m_eth_rx_dst_mac_addr(m_eth_rx_dst_mac_addr),
    .m_eth_rx_type(m_eth_rx_type),    

    // IP Frame Payload 
    .m_rx_axis_tdata(ip_rx_axis_data),
    .m_rx_axis_tvalid(ip_rx_axis_tvalid),
    .m_rx_axis_tlast(ip_rx_axis_tlast),
    .m_rx_axis_trdy(ip_rx_axis_trdy),

    // Status Flags 
    .bad_packet()
);

/* Output Signals */

assign m_udp_ip_hdr_valid = udp_hdr_valid & ip_hdr_valid;
assign s_tx_hdr_rdy = s_udp_hdr_trdy & s_ip_hdr_trdy;

endmodule : udp_ip_stack