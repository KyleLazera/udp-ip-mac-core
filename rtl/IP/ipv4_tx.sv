`timescale 1ns / 1ps

/* This is an IPv4 Tranmission module that will be used to encapsulate data within an IP frame.
 * This module will recieve raw data as well as certain IP header fields for the encapsulation
 * and will output the data as an axi-stream data packet.
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
 *    Time to Live - Mainly used when passing ethernet packets through routers to avod the packet getting stuck in a loop
 */

module ipv4_tx
#(
   parameter AXI_STREAM_WIDTH = 8
)(
   input wire i_clk,
   input wire i_reset_n,

   /* AXI Stream Payload Inputs */
   input wire [AXI_STREAM_WIDTH-1:0] s_tx_axis_tdata,                   // Raw Payload data via AXI Stream
   input wire s_tx_axis_tvalid,                                         // tvalid for payload data 
   input wire s_tx_axis_tlast,                                          // last byte of payload
   output wire s_tx_axis_trdy,                                          // Indicates IP tx is ready for payload data

   /* IP Header/Package Inputs */
   input wire ip_tx_hdr_valid,                                          // Indicates the header inputs are valid
   output wire ip_tx_hdr_rdy,                                           // IP tx is ready for next header inputs
   input wire [7:0] ip_tx_hdr_type,                                     // Type of Service Field
   input wire [15:0] ip_tx_total_length,                                // Total length of payload
   input wire [7:0] ip_tx_protocol,                                     // L4 protocol (UDP/TCP)
   input wire [31:0] ip_tx_src_ip_addr,                                 // Source IP address
   input wire [31:0] ip_tx_dst_ip_addr,                                 // Destination IP address

   /* AXI Stream Packaged IP Outputs */
   output wire [AXI_STREAM_WIDTH-1:0] m_tx_axis_tdata,                  // Packaged IP data (header & payload)
   output wire m_tx_axis_tvalid,                                        // valid signal for tdata
   output wire m_tx_axis_tlast,                                         // last byte of IP package
   input wire m_tx_axis_trdy                                            // Back pressure from downstream module indciating it is ready
);

// IP Header Constants 
localparam [3:0] IPv4_VERSION = 4'd4;
localparam [3:0] IPv4_HDR_LENGTH = 4'd5;
localparam [15:0] IPv4_IDENTIFICATION = 16'd0;
localparam [2:0] IPV4_FLAGS = 3'd0;
localparam [12:0] IPv4_FRAG_OFFSET = 13'd0;
localparam [7:0] IPv4_TTL = 8'd64;

// State Encoding 
localparam [1:0] IDLE = 2'b00;
localparam [1:0] HEADER = 2'b01; 
localparam [1:0] PAYLOAD = 2'b10;

// IP Header fields 
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

// IP Header Constants
assign ip_hdr_version = IPv4_VERSION;
assign ip_hdr_length = IPv4_HDR_LENGTH;
assign ip_hdr_id = IPv4_IDENTIFICATION;
assign ip_hdr_flags = IPV4_FLAGS;
assign ip_hdr_frag_offset = IPv4_FRAG_OFFSET;
assign ip_hdr_ttl = IPv4_TTL;

// Intermediary Signals/Datapath
reg [1:0] state_reg = IDLE; 
reg [AXI_STREAM_WIDTH-1:0] m_tx_axis_tdata_reg = 8'b0;
reg m_tx_axis_tvalid_reg = 1'b0; 
reg m_tx_axis_tlast_reg = 1'b0;     
reg s_tx_axis_trdy_reg = 1'b0;
reg ip_tx_hdr_rdy_reg = 1'b0;
reg [4:0] ip_hdr_cnt = 5'b0;

/* Checksum Calculation Logic */ 
reg [15:0] ip_hdr_checksum_field = 16'b0;
reg ip_checksum_en = 1'b0;    

wire [15:0] ip_checksum;

ipv4_checksum hdr_cheksum(
   .i_clk(i_clk),
   .i_reset_n(i_reset_n),
   .ip_hdr_field(ip_hdr_checksum_field),
   .ip_checksum_en(ip_checksum_en),
   .ip_hdr_checksum(ip_checksum)
);

/* IP Packet Encapsulation Block */

always @(posedge i_clk) begin
   if(~i_reset_n) begin
      state_reg <= IDLE;
      //Datapath registers
      m_tx_axis_tdata_reg <= 8'b0;
      m_tx_axis_tvalid_reg <= 1'b0; 
      m_tx_axis_tlast_reg <= 1'b0;  
      ip_tx_hdr_rdy_reg <= 1'b0;       
      // Checksum Registers
      ip_hdr_cnt <= 5'b0;
      ip_hdr_checksum_field <= 16'b0;
      ip_checksum_en <= 1'b0;
      checksum_sum <= 17'b0;
   end else begin
      // Default signals 
      s_tx_axis_trdy_reg <= 1'b0;
      m_tx_axis_tvalid_reg <= 1'b0;
      m_tx_axis_tlast_reg <= 1'b0;      
      ip_tx_hdr_rdy_reg <= 1'b0;
      ip_checksum_en <= 1'b0;

      // FSM
      case(state_reg)
         IDLE : begin

            // If the up-stream module has valid data, and the down-stream module can recieve
            // data, assert the header_rdy flag to latch the header inputs
            ip_tx_hdr_rdy_reg <= s_tx_axis_tvalid & m_tx_axis_trdy;

            // If the header handshake is complete (hdr_valid & hdr_rdy), latch the inputs and
            // start the transmission/encapsulation process
            if(ip_tx_hdr_valid & ip_tx_hdr_rdy_reg) begin
               //Latch the relevant IP Header fields
               ip_hdr_type <= ip_tx_hdr_type;
               ip_hdr_total_length <= ip_tx_total_length;
               ip_hdr_protocol <= ip_tx_protocol;
               ip_hdr_src_ip_addr <= ip_tx_src_ip_addr;
               ip_hdr_dst_ip_addr <= ip_tx_dst_ip_addr;

               //Initially set checksum to zero, it is updated once the checksum has been calculated
               ip_hdr_checksum <= 16'b0;
               ip_hdr_cnt <= 5'b0;

               //Send the initial header values to checksum module - This will allow us to
               // have the checksum calculated by the time we need it
               ip_checksum_en <= 1'b1;
               ip_hdr_checksum_field <= {ip_hdr_version, ip_hdr_length, ip_tx_hdr_type};
               checksum_sum <= {ip_hdr_version, ip_hdr_length, ip_tx_hdr_type};

               // Drive the first part of the header along with the tvalid flag
               m_tx_axis_tdata_reg <= {ip_hdr_version, ip_hdr_length};
               m_tx_axis_tvalid_reg <= 1'b1;

               state_reg <= HEADER;
            end     


         end
         HEADER : begin
            ip_checksum_en <= 1'b1;
            m_tx_axis_tvalid_reg <= 1'b1;
            
            // Only increment the IP header count if the slave device (downstream module) is ready
            //ip_hdr_cnt <= ip_hdr_cnt + m_tx_axis_trdy;
            if(m_tx_axis_trdy & m_tx_axis_tvalid_reg) begin
            // Based on the header counter, determine which field of the header to transmit downstream
            case(ip_hdr_cnt)
               5'd0: begin
                  m_tx_axis_tdata_reg <= ip_hdr_type;
                  ip_hdr_checksum_field <= ip_hdr_total_length;
               end
               5'd1: begin
                  m_tx_axis_tdata_reg <= ip_hdr_total_length[15:8];
                  ip_hdr_checksum_field <= {ip_hdr_flags, ip_hdr_frag_offset};             
               end
               5'd2: begin
                  m_tx_axis_tdata_reg <= ip_hdr_total_length[7:0];
                  ip_hdr_checksum_field <= {ip_hdr_ttl, ip_hdr_protocol};
               end
               5'd3: begin
                  m_tx_axis_tdata_reg <= ip_hdr_id[15:8];
                  ip_hdr_checksum_field <= ip_hdr_src_ip_addr[31:16];
               end
               5'd4: begin
                  m_tx_axis_tdata_reg <= ip_hdr_id[7:0];
                  ip_hdr_checksum_field <= ip_hdr_src_ip_addr[15:0];                
               end   
               5'd5: begin
                  m_tx_axis_tdata_reg <= {ip_hdr_flags, ip_hdr_frag_offset[12:8]};
                  ip_hdr_checksum_field <= ip_hdr_dst_ip_addr[31:16];
               end
               5'd6: begin
                  m_tx_axis_tdata_reg <= ip_hdr_frag_offset[7:0];
                  ip_hdr_checksum_field <= ip_hdr_dst_ip_addr[15:0];
               end
               5'd7: begin
                  m_tx_axis_tdata_reg <= ip_hdr_ttl;
                                    
               end
               5'd8: begin
                  m_tx_axis_tdata_reg <= ip_hdr_protocol;
                  ip_hdr_checksum <= ip_checksum;
               end
               5'd9: begin
                  m_tx_axis_tdata_reg <= ip_hdr_checksum[15:8]; 
               end 
               5'd10: begin
                  m_tx_axis_tdata_reg <= ip_hdr_checksum[7:0]; 
               end                 
               5'd11: begin
                  m_tx_axis_tdata_reg <= ip_hdr_src_ip_addr[31:24];                  
               end
               5'd12: begin
                  m_tx_axis_tdata_reg <= ip_hdr_src_ip_addr[23:16];                                   
               end    
               5'd13: begin
                  m_tx_axis_tdata_reg <= ip_hdr_src_ip_addr[15:8]; 
               end 
               5'd14: begin
                  m_tx_axis_tdata_reg <= ip_hdr_src_ip_addr[7:0];
               end 
               5'd15: begin
                  m_tx_axis_tdata_reg <= ip_hdr_dst_ip_addr[31:24]; 
               end 
               5'd16: begin
                  m_tx_axis_tdata_reg <= ip_hdr_dst_ip_addr[23:16]; 
               end  
               5'd17: begin
                  m_tx_axis_tdata_reg <= ip_hdr_dst_ip_addr[15:8]; 
               end 
               5'd18: begin
                  m_tx_axis_tdata_reg <= ip_hdr_dst_ip_addr[7:0]; 
                  s_tx_axis_trdy_reg <= 1'b1;
                  state_reg <= PAYLOAD;
               end                                                                  
            endcase
            ip_hdr_cnt <= ip_hdr_cnt + 1'b1;
            end

         end
         PAYLOAD : begin
            s_tx_axis_trdy_reg <= 1'b1;

            if(s_tx_axis_trdy_reg & s_tx_axis_tvalid & m_tx_axis_trdy) begin
               m_tx_axis_tdata_reg <= s_tx_axis_tdata;
               m_tx_axis_tvalid_reg <= s_tx_axis_tvalid;
               m_tx_axis_tlast_reg <= s_tx_axis_tlast;

               //If we just sampled the final byte of data, return to the IDLE state on the next
               // clock edge
               if(s_tx_axis_tlast & m_tx_axis_tvalid_reg) begin
                  s_tx_axis_trdy_reg <= 1'b0;
                  state_reg <= IDLE;
               end

            end         

         end
      endcase
   end
end

assign s_tx_axis_trdy = s_tx_axis_trdy_reg;
assign ip_tx_hdr_rdy = ip_tx_hdr_rdy_reg;
assign m_tx_axis_tdata = m_tx_axis_tdata_reg;
assign m_tx_axis_tvalid = m_tx_axis_tvalid_reg;
assign m_tx_axis_tlast = m_tx_axis_tlast_reg;

endmodule 