`timescale 1ns / 1ps

/* This is an IPv4 Tranmission module that will be used to encapsulate data within an IP frame.
 * This module will recieve raw data as well as certain IP header fields in parallel for the encapsulation
 * and will output the data as an axi-stream data packet along with the ethernet header in parallel.
 * To achieve a lower-latency for the IP stack, the option to encapsulate the IP packet within the Ethernet Header is
 * available via the parameter ETH_FRAME.
 * For reference an IP frame is displayed below:
 *
 *  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 *  +---------------+---------------+---------------+---------------+
 *  |Version|  IHL  |     Type      |          Total Length         |
 *  +---------------+---------------+---------------+---------------+
 *  |         Identification        |Flags|     Fragment Offset     |
 *  +---------------+---------------+---------------+---------------+
 *  | Time to Live  |    Protocol   |        Header Checksum        |
 *  +---------------+---------------+---------------+---------------+
 *  |                       Source IP Address                       |
 *  +---------------+---------------+---------------+---------------+
 *  |                    Destination IP Address                     |
 *  +---------------+---------------+---------------+---------------+
 *
 * Field	                    Size (bits)  Description
 *
 * Version	                    4	                Differentiates between IPv4 or IPv6 (always 4 for IPv4)
 * IHL (Header Length)	        4	                Number of 32-bit words in header - Determines if options are used
 * Type of Service (TOS)	     8	                Differentiated services / priority
 * Total Length	              16	                Total length of the IP packet (header + data)
 * Identification	              16	                ID for fragmentation and reassembly
 * Flags	                       3	                Fragmentation control (DF, MF bits)
 * Fragment Offset	           13	                Byte offset of fragment (in 8-byte units)
 * Time To Live (TTL)	        8	                Decremented router to avoid packet looping within network; 0 = discard
 * Protocol	                    8	                Higher layer protocol: 0x11 = UDP, 0x06 = TCP
 * Header Checksum	           16	                Checksum for IP header only
 * Source IP Address	           32	                IPv4 address of sender
 * Destination IP Address	     32	                IPv4 address of receiver
 * Options (optional)	        variable  	       Optional — only present if IHL > 5
 * Data (payload)	              variable	          Payload to transmit
 * 
 * Due to this project being specifically meant for a point to point ethernet link, certain 
 * fields will not be used:
 *    IHL - This will be set to 5. If options are used this changes, but for now this is always 5
 *    Identification, Flags & Fragment Offset - These are not needed because we will limit the packet size to 1472 to meet ethernet MTU
 *    Time to Live - Mainly used when passing ethernet packets through routers to avoid the packet getting stuck in a loop
 */

module ipv4_tx
#(
   parameter AXI_STREAM_WIDTH = 8,
   parameter ETH_FRAME = 1,                                             // Encapsulates IP frame within an ethernet frame
   parameter STREAM_PAYLOAD = 1                                         // When STREAM_PAYLOAD=1, this indicates the payload is begin streamed from an
                                                                        // up-stream module rather than being buffered by teh up-stream module. This means
                                                                        // the total packet length will not be known immediately, and cannot be sent during
                                                                        // the IP header phase along with the checksum.
)(
   input wire i_clk,
   input wire i_reset_n,

   /* AXI Stream Payload Inputs */
   input wire [AXI_STREAM_WIDTH-1:0] s_tx_axis_tdata,                   // Raw Payload data via AXI Stream
   input wire s_tx_axis_tvalid,                                         // tvalid for payload data 
   input wire s_tx_axis_tlast,                                          // last byte of payload
   output wire s_tx_axis_trdy,                                          // Indicates IP tx is ready for payload data

   /* IP & Ethernet Header/Package Inputs */
   input wire s_ip_tx_hdr_valid,                                        // Indicates the header inputs are valid
   output wire s_ip_tx_hdr_rdy,                                         // IP tx is ready for next header inputs
   input wire [7:0] s_ip_tx_hdr_type,                                   // Type of Service Field
   input wire [7:0] s_ip_tx_protocol,                                   // L4 protocol (UDP/TCP)
   input wire [31:0] s_ip_tx_src_ip_addr,                               // Source IP address
   input wire [31:0] s_ip_tx_dst_ip_addr,                               // Destination IP address
   input wire [47:0] s_eth_tx_src_mac_addr,                             //Eth source mac address
   input wire [47:0] s_eth_tx_dst_mac_addr,                             //Eth destination mac address   
   input wire [15:0] s_eth_tx_type,                                     //Eth type  

   /* AXI Stream Packaged IP Outputs */
   output wire [AXI_STREAM_WIDTH-1:0] m_tx_axis_tdata,                  // Packaged IP data (header & payload)
   output wire m_tx_axis_tvalid,                                        // valid signal for tdata
   output wire m_tx_axis_tlast,                                         // last byte of IP package
   input wire m_tx_axis_trdy,                                           // Back pressure from downstream module indciating it is ready

   /* IP Header Outputs */
   output wire m_ip_tx_hdr_tvalid,                                      // Indicates the ip total length & checsum fields are valid
   output wire [15:0] m_ip_tx_total_length,
   output wire [15:0] m_ip_tx_checksum,

   /* Ethernet Header Outputs */
   input wire m_eth_hdr_trdy,
   output wire m_eth_hdr_tvalid,
   output wire [47:0] m_eth_src_mac_addr,                               //Eth source mac address
   output wire [47:0] m_eth_dst_mac_addr,                               //Eth destination mac address   
   output wire [15:0] m_eth_type                                        //Eth type        
);

/* IP Header Fields that will remain constant */
localparam [3:0] IPv4_VERSION = 4'd4;
localparam [3:0] IPv4_HDR_LENGTH = 4'd5;
localparam [15:0] IPv4_IDENTIFICATION = 16'd0;
localparam [2:0] IPv4_FLAGS = 3'd0;
localparam [12:0] IPv4_FRAG_OFFSET = 13'd0;
localparam [7:0] IPv4_TTL = 8'd64;
localparam [16:0] IPv4_HDR_BYTES = 16'd20;

/* State Encoding */
localparam [1:0] IDLE = 2'b00;
localparam [1:0] IP_HEADER = 2'b01; 
localparam [1:0] ETH_HEADER = 2'b10;
localparam [1:0] PAYLOAD = 2'b11;

/* Data Path IP Header Registers */
reg [3:0] ip_hdr_version;
reg [3:0] ip_hdr_length;
reg [7:0] ip_hdr_type;
reg [15:0] ip_hdr_total_length;
reg [15:0] ip_hdr_id;
reg [2:0] ip_hdr_flags;
reg [12:0] ip_hdr_frag_offset;
reg [7:0] ip_hdr_ttl;
reg [7:0] ip_hdr_protocol;
reg [15:0] ip_hdr_checksum;
reg [31:0] ip_hdr_src_ip_addr;                                 
reg [31:0] ip_hdr_dst_ip_addr;   

reg [159:0] ip_hdr;
reg [111:0] eth_hdr;

/* Data Path Ethernet Header Registers */
reg [15:0] eth_type_reg;
reg [47:0] eth_src_mac_addr_reg;
reg [47:0] eth_dst_mac_addr_reg;

/* Data Path Registers */
reg [1:0] state_reg = IDLE; 
reg [AXI_STREAM_WIDTH-1:0] m_tx_axis_tdata_reg = 8'b0;
reg m_tx_axis_tvalid_reg = 1'b0; 
reg m_tx_axis_tlast_reg = 1'b0;     
reg m_tx_axis_trdy_reg = 1'b0;
reg s_tx_axis_trdy_reg = 1'b0;
reg s_ip_hdr_rdy_reg = 1'b0;
reg m_eth_hdr_tvalid_reg = 1'b0;

/* Flag/Status Registers */
reg hdr_latched = 1'b0;
reg m_ip_tx_hdr_tvalid_reg = 1'b0;
reg [15:0] pckt_cntr = 16'b0;
reg [4:0] hdr_cntr = 5'b0;

/* Checksum Calculation Logic */ 
reg [16:0] int_checksum_sum = 16'b0;
reg [15:0] ip_checksum_sum = 16'b0;
reg [15:0] checksum_pckt_diff;
reg fold_checksum_carry = 1'b0;

reg [16:0] ip_checksum_precompute = 17'b0;
reg [15:0] ip_checksum_carry = 16'b0;

reg [16:0] src_ip_checksum_precompute = 17'b0;
reg [15:0] src_ip_checksum_carry = 16'b0;

reg [16:0] dst_ip_checksum_precompute = 17'b0;
reg [15:0] dst_ip_checksum_carry = 16'b0;

reg [16:0] ip_addr_checksum_precompute = 17'b0;
reg [15:0] ip_addr_checksum_carry = 16'b0;

reg [16:0] ip_hdr_checksum_precompute = 17'b0;
reg [15:0] ip_hdr_checksum_carry = 16'b0;

/*  Assign IP Header Constants */
assign ip_hdr_version = IPv4_VERSION;
assign ip_hdr_length = IPv4_HDR_LENGTH;
assign ip_hdr_id = IPv4_IDENTIFICATION;
assign ip_hdr_flags = IPv4_FLAGS;
assign ip_hdr_frag_offset = IPv4_FRAG_OFFSET;
assign ip_hdr_ttl = IPv4_TTL;

/* IP Checksum Logic */
always @(posedge i_clk) begin

   src_ip_checksum_precompute <= ip_hdr_src_ip_addr[31:16] + ip_hdr_src_ip_addr[15:0]; 
   dst_ip_checksum_precompute <= ip_hdr_dst_ip_addr[31:16] + ip_hdr_dst_ip_addr[15:0];
   ip_checksum_precompute <= {ip_hdr_version, ip_hdr_length, ip_hdr_type} + {ip_hdr_ttl, ip_hdr_protocol};

   src_ip_checksum_carry <= src_ip_checksum_precompute[15:0] + src_ip_checksum_precompute[16];
   dst_ip_checksum_carry <= dst_ip_checksum_precompute[15:0] + dst_ip_checksum_precompute[16];
   ip_checksum_carry <= ip_checksum_precompute[15:0] + ip_checksum_precompute[16];

   ip_addr_checksum_precompute <= src_ip_checksum_carry + dst_ip_checksum_carry;

   ip_addr_checksum_carry <= ip_addr_checksum_precompute[15:0] + ip_addr_checksum_precompute[16];

   ip_hdr_checksum_precompute <= ip_addr_checksum_carry + ip_checksum_carry;

   ip_checksum_sum <= ip_hdr_checksum_precompute[15:0] + ip_hdr_checksum_precompute[16];

end

/* IP Packet Encapsulation Block */

always @(posedge i_clk) begin
   if(~i_reset_n) begin
      state_reg <= IDLE;
      
      //Datapath registers
      m_tx_axis_tdata_reg <= 8'b0;
      m_tx_axis_tvalid_reg <= 1'b0; 
      m_tx_axis_tlast_reg <= 1'b0;  
      s_ip_hdr_rdy_reg <= 1'b0;
      m_eth_hdr_tvalid_reg <= 1'b0; 
      ip_hdr <= 160'b0;     
      eth_hdr <= 112'b0;

      /* Checksum Registers */    
      int_checksum_sum <= 17'b0;
      //ip_checksum_sum <= 16'b0;

      //Flag/Status Registers
      hdr_latched <= 1'b0;
      m_ip_tx_hdr_tvalid_reg <= 1'b0;
      hdr_cntr <= 5'b0;
      pckt_cntr <= 16'b0;

   end else begin
      // Default signals 
      s_tx_axis_trdy_reg <= 1'b0;
      m_tx_axis_tvalid_reg <= 1'b0;
      m_tx_axis_tlast_reg <= 1'b0;      
      s_ip_hdr_rdy_reg <= 1'b0;
      m_eth_hdr_tvalid_reg <= 1'b1;   

      m_tx_axis_trdy_reg <= m_tx_axis_trdy;

      // FSM
      case(state_reg)
         IDLE : begin
            hdr_cntr <= 5'b0;
            pckt_cntr <= 16'b0;   
            s_ip_hdr_rdy_reg <= 1'b1;         
            m_eth_hdr_tvalid_reg <= 1'b0; 

            //////////////////////////////////////////////////////////////////////////////////////////
            // If the up-stream module has valid header data, latch the hdr data and 
            // the first byte to be output to the downstream module, & move to the next state.
            //////////////////////////////////////////////////////////////////////////////////////////
            if(s_ip_tx_hdr_valid & s_ip_hdr_rdy_reg) begin
               // Latch Header data
               ip_hdr_type <= s_ip_tx_hdr_type;
               ip_hdr_protocol <= s_ip_tx_protocol;
               ip_hdr_src_ip_addr <= s_ip_tx_src_ip_addr;
               ip_hdr_dst_ip_addr <= s_ip_tx_dst_ip_addr;
               
               //Initially set checksum to 0 - this is changed after it is calculated
               ip_hdr_checksum <= 16'b0;
               m_ip_tx_hdr_tvalid_reg <= 1'b0;
               eth_type_reg <= s_eth_tx_type;
               eth_src_mac_addr_reg <= s_eth_tx_src_mac_addr;
               eth_dst_mac_addr_reg <= s_eth_tx_dst_mac_addr;
               
               /* Reset checksum reg & handshaking signals */
               int_checksum_sum <= 17'b0;
               //ip_checksum_sum <= 16'b0;

               m_tx_axis_tvalid_reg <= 1'b1;
               s_ip_hdr_rdy_reg <= 1'b0;

               // Create IP header
               ip_hdr <= {
                  ip_hdr_version, ip_hdr_length, s_ip_tx_hdr_type,
                  16'hDEAD, ip_hdr_id, ip_hdr_flags, ip_hdr_frag_offset,
                  ip_hdr_ttl, s_ip_tx_protocol, 16'hBEEF, s_ip_tx_src_ip_addr,
                  s_ip_tx_dst_ip_addr
               };
              

               if(ETH_FRAME) begin
                  //////////////////////////////////////////////////////////////////////////////////////////////
                  // To improve the overall latency of the design, drive the first byte of the ethernet header
                  // in this state, and create an adjusted ethernet header (shifted to the left by 8 bits)
                  //////////////////////////////////////////////////////////////////////////////////////////////
                  
                  m_tx_axis_tdata_reg <= s_eth_tx_dst_mac_addr[47:40];
                  eth_hdr <= {s_eth_tx_dst_mac_addr[39:0], s_eth_tx_src_mac_addr, s_eth_tx_type, 8'h00};                 
                  
                  // If we are outputting an encapsulated ethernet frame, do not raise the hdr valid flag
                  // because the ethernet header data will be output on the AXI-Stream lines.
                  m_eth_hdr_tvalid_reg <= 1'b0;
                  state_reg <= ETH_HEADER;
               end else begin
                  
                  //////////////////////////////////////////////////////////////////////////////////////////////
                  // To improve the overall latency of teh design, drive the first byte of the IP header
                  // in this state, and create an adjusted IP header (shifted to the left by 8 bits), similar to
                  // the ethernet header.
                  //////////////////////////////////////////////////////////////////////////////////////////////                                  
                  m_tx_axis_tdata_reg <= {ip_hdr_version, ip_hdr_length}; 
                  ip_hdr <= {
                     s_ip_tx_hdr_type, 16'hDEAD, ip_hdr_id, ip_hdr_flags,
                     ip_hdr_frag_offset, ip_hdr_ttl, s_ip_tx_protocol, 
                     16'hBEEF, s_ip_tx_src_ip_addr, s_ip_tx_dst_ip_addr, 8'h00};                  
                  
                  
                  m_eth_hdr_tvalid_reg <= 1'b1;
                  state_reg <= IP_HEADER;
               end    
            end

         end
         ETH_HEADER: begin
            m_tx_axis_tvalid_reg <= 1'b1;

            // Before transmitting data, ensure the down-stream module has the trdy
            // flag set, indicating it is ready to recieve data.
            if(m_tx_axis_trdy_reg & m_tx_axis_tvalid_reg) begin

               hdr_cntr <= hdr_cntr + 1;

               m_tx_axis_tdata_reg <= eth_hdr[111 -: 8];
               eth_hdr <= eth_hdr << 8;

               if(hdr_cntr == 5'd12) begin    
                  hdr_cntr <= 5'b0;  
                  state_reg <= IP_HEADER;
               end
            end

         end
         IP_HEADER: begin
            m_tx_axis_tvalid_reg <= 1'b1;
            
            ////////////////////////////////////////////////////////////////////////////////////////////////
            // The IP total length and checksum fields require the full length of the payload
            // (including the IP header) to be known. To achieve this (without requiring a user to
            // input the payload size) either a buffer would be needed to store the data and count 
            // the bytes (adds quite a lot of latency) or the value is calculated in parallel with the 
            // payload and is inserted at the end (ethernet MAC). The latter option is selected for this
            // design, and therefore, the IP length and checksum fields are initially filled with temporary
            // values DEAD & BEEF.
            ////////////////////////////////////////////////////////////////////////////////////////////////

            if(m_tx_axis_trdy_reg & m_tx_axis_tvalid_reg) begin

               m_tx_axis_tdata_reg <= ip_hdr[159 -: 8];
               ip_hdr = ip_hdr << 8;

               if(hdr_cntr == 5'd19) begin
                  s_tx_axis_trdy_reg <= m_tx_axis_trdy;
                  checksum_pckt_diff <= 16'hFFFF - ip_checksum_sum;
                  pckt_cntr <= IPv4_HDR_BYTES + 1;                                    
                  state_reg <= PAYLOAD;
               end
               
               hdr_cntr <= hdr_cntr + 1'b1;
            end        

         end
         PAYLOAD : begin
            s_tx_axis_trdy_reg <= m_tx_axis_trdy;
            m_tx_axis_tvalid_reg <= 1'b1;
            m_eth_hdr_tvalid_reg <= (ETH_FRAME) ? 1'b0 : !hdr_latched;

            // Make sure AXI Handshake is active
            if(m_tx_axis_trdy_reg & s_tx_axis_tvalid) begin
               m_tx_axis_tdata_reg <= s_tx_axis_tdata;
               m_tx_axis_tlast_reg <= s_tx_axis_tlast;

               //If we just sampled the final byte of data, return to the IDLE state on the next
               // clock edge
               if(s_tx_axis_tlast & m_tx_axis_tvalid_reg) begin
                  s_tx_axis_trdy_reg <= 1'b0;
                  s_ip_hdr_rdy_reg <= 1'b1;

                  // Output the delayed header fields
                  ip_hdr_checksum <= ip_checksum_sum + pckt_cntr;
                  ip_hdr_total_length <= pckt_cntr;
                  m_ip_tx_hdr_tvalid_reg <= 1'b1;

                  state_reg <= IDLE;
               end

               fold_checksum_carry <= (pckt_cntr > checksum_pckt_diff);
               pckt_cntr <= pckt_cntr + 1;
            end   

            if(m_eth_hdr_trdy & m_eth_hdr_tvalid_reg) 
               hdr_latched <= 1'b1;                     

         end
      endcase
   end
end

/* Ethernet Header Output Signals */
assign m_eth_hdr_tvalid = m_eth_hdr_tvalid_reg;
assign m_eth_src_mac_addr = eth_src_mac_addr_reg;                       
assign m_eth_dst_mac_addr = eth_dst_mac_addr_reg;                  
assign m_eth_type = eth_type_reg;

/* Ethernet Payload Output Signals */
assign m_tx_axis_tdata = m_tx_axis_tdata_reg;
assign m_tx_axis_tvalid = m_tx_axis_tvalid_reg;
assign m_tx_axis_tlast = m_tx_axis_tlast_reg;

/////////////////////////////////////////////////////////////////////////////////////////////
// If we are in the PAYLOAD state, we need to propogate the trdy value from the down-stream
// module to the up-stream module. This is needed to make sure the up-stream module is not
// sending data while the down-stream module is not ready.
/////////////////////////////////////////////////////////////////////////////////////////////

assign s_tx_axis_trdy = s_tx_axis_trdy_reg;
assign s_ip_tx_hdr_rdy = s_ip_hdr_rdy_reg;

/* IP Header Outputs */
assign m_ip_tx_hdr_tvalid = m_ip_tx_hdr_tvalid_reg;
assign m_ip_tx_total_length = ip_hdr_total_length;
assign m_ip_tx_checksum = ~(ip_hdr_checksum + fold_checksum_carry);

endmodule 