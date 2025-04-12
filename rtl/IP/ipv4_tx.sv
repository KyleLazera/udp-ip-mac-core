`timescale 1ns / 1ps

/* This is an IPv4 Tranmission module that will be used to encapsulate data within an IP frame.
 * This module will recieve raw data as well as certain IP header fields in parallel for the encapsulation
 * and will output the data as an axi-stream data packet along with th ethernet header in parallel.
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

   /* IP & Ethernet Header/Package Inputs */
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

   /* AXI Stream Packaged IP Outputs */
   output wire [AXI_STREAM_WIDTH-1:0] m_tx_axis_tdata,                  // Packaged IP data (header & payload)
   output wire m_tx_axis_tvalid,                                        // valid signal for tdata
   output wire m_tx_axis_tlast,                                         // last byte of IP package
   input wire m_tx_axis_trdy,                                           // Back pressure from downstream module indciating it is ready

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
localparam [2:0] IPV4_FLAGS = 3'd0;
localparam [12:0] IPv4_FRAG_OFFSET = 13'd0;
localparam [7:0] IPv4_TTL = 8'd64;

/* State Encoding */
localparam [1:0] IDLE = 2'b00;
localparam [1:0] HEADER = 2'b01; 
localparam [1:0] PAYLOAD = 2'b10;

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

/* Data Path Ethernet Header Registers */
reg [15:0] eth_type_reg;
reg [47:0] eth_src_mac_addr_reg;
reg [47:0] eth_dst_mac_addr_reg;

/* Data Path Registers */
reg [1:0] state_reg = IDLE; 
reg [AXI_STREAM_WIDTH-1:0] m_tx_axis_tdata_reg = 8'b0;
reg m_tx_axis_tvalid_reg = 1'b0; 
reg m_tx_axis_tlast_reg = 1'b0;     
reg s_tx_axis_trdy_reg = 1'b0;
reg s_ip_hdr_rdy_reg;
reg m_eth_hdr_rdy_reg;

/* Flag/Status Registers */
reg hdr_latched = 1'b0;
reg [4:0] ip_hdr_cnt = 5'b0;

/* Checksum Calculation Logic */ 
reg [15:0] checksum_sum = 16'b0;

////////////////////////////////////////////////////////////////////////
// The IP Header checksum is calculated by first dividing the IP Header into
// 16 bit fields. Each 16 bit field is added together, however, if there is a 
// carry out, the carry is added back to the lsb of the 16-bit sum. An example
// is provided below using 8 bit values:
//
// Operand 1:   10011001
// Operand 2:  +11101101
// Result:     110000110
//
// Because the result has a carry out of 1, we add this back to the Result:
//
// Operand 1:   10000110
// Operand 2:  +       1
// Result:      10000111
//////////////////////////////////////////////////////////////////////// 
function [15:0] ip_checksum(input [15:0] sum, input [15:0] hdr_field);
   //Intermediary sum
   reg [16:0] int_sum;
   begin
      int_sum = sum + hdr_field;
      ip_checksum = int_sum[15:0] + int_sum[16]; 
   end 
endfunction : ip_checksum


/*  Assign IP Header Constants */
assign ip_hdr_version = IPv4_VERSION;
assign ip_hdr_length = IPv4_HDR_LENGTH;
assign ip_hdr_id = IPv4_IDENTIFICATION;
assign ip_hdr_flags = IPV4_FLAGS;
assign ip_hdr_frag_offset = IPv4_FRAG_OFFSET;
assign ip_hdr_ttl = IPv4_TTL;

/* IP Packet Encapsulation Block */

always @(posedge i_clk) begin
   if(~i_reset_n) begin
      state_reg <= IDLE;
      
      //Datapath registers
      m_tx_axis_tdata_reg <= 8'b0;
      m_tx_axis_tvalid_reg <= 1'b0; 
      m_tx_axis_tlast_reg <= 1'b0;  
      s_ip_hdr_rdy_reg <= 1'b0;
      m_eth_hdr_rdy_reg <= 1'b0;      

      // Checksum Registers      
      checksum_sum <= 16'b0;

      //Flag/Status Registers
      hdr_latched <= 1'b0;
      ip_hdr_cnt <= 5'b0;

   end else begin
      // Default signals 
      s_tx_axis_trdy_reg <= 1'b0;
      m_tx_axis_tvalid_reg <= 1'b0;
      m_tx_axis_tlast_reg <= 1'b0;      
      s_ip_hdr_rdy_reg <= 1'b0;
      m_eth_hdr_rdy_reg <= 1'b0;   

      // FSM
      case(state_reg)
         IDLE : begin
            ip_hdr_cnt <= 5'b0;            
            m_eth_hdr_rdy_reg <= 1'b0; 
             
            // ip header handshaking logic 
            if(hdr_latched || s_ip_hdr_rdy_reg & s_ip_tx_hdr_valid)      
               s_ip_hdr_rdy_reg <= 1'b0;
            else
               s_ip_hdr_rdy_reg <= 1'b1;

            //Latch IP and Ethernet Header Data if valid and rdy handshake is succesfull
            if(s_ip_hdr_rdy_reg & s_ip_tx_hdr_valid) begin
               
               ip_hdr_type <= s_ip_tx_hdr_type;
               ip_hdr_total_length <= s_ip_tx_total_length;
               ip_hdr_protocol <= s_ip_tx_protocol;
               ip_hdr_src_ip_addr <= s_ip_tx_src_ip_addr;
               ip_hdr_dst_ip_addr <= s_ip_tx_dst_ip_addr;
               //Initially set checksum to 0 - this is changed after it is calculated
               ip_hdr_checksum <= 16'b0;
               eth_type_reg <= m_eth_type;
               eth_src_mac_addr_reg <= m_eth_src_mac_addr;
               eth_dst_mac_addr_reg <= m_eth_dst_mac_addr;

               //Indicate the header has been latched
               hdr_latched <= 1'b1;
            end 

            // If we have latched header data and both the up-stream and down-stream modules
            // are ready to recieve data, begin the encappsulation process.
            if(hdr_latched & m_tx_axis_trdy & s_tx_axis_tvalid) begin 
               hdr_latched <= 1'b0;
               checksum_sum <= 16'b0;

               // Drive the first part of the header along with the tvalid flag
               m_tx_axis_tdata_reg <= {ip_hdr_version, ip_hdr_length};
               m_tx_axis_tvalid_reg <= 1'b1;
               
               state_reg <= HEADER;               
            end
         end
         HEADER : begin
            m_tx_axis_tvalid_reg <= 1'b1;
            
            if(m_tx_axis_trdy & m_tx_axis_tvalid_reg) begin
               // Based on the header counter, determine which field of the header to transmit downstream
               case(ip_hdr_cnt)
                  5'd0: begin
                     m_tx_axis_tdata_reg <= ip_hdr_type;
                     checksum_sum <= ip_checksum(checksum_sum, {ip_hdr_version, ip_hdr_length, ip_hdr_type});
                  end
                  5'd1: begin
                     m_tx_axis_tdata_reg <= ip_hdr_total_length[15:8];
                     checksum_sum <= ip_checksum(checksum_sum, ip_hdr_total_length);            
                  end
                  5'd2: begin
                     m_tx_axis_tdata_reg <= ip_hdr_total_length[7:0];
                     checksum_sum <= ip_checksum(checksum_sum, {ip_hdr_flags, ip_hdr_frag_offset});
                  end
                  5'd3: begin
                     m_tx_axis_tdata_reg <= ip_hdr_id[15:8];
                     checksum_sum <= ip_checksum(checksum_sum, {ip_hdr_ttl, ip_hdr_protocol});
                  end
                  5'd4: begin
                     m_tx_axis_tdata_reg <= ip_hdr_id[7:0];
                     checksum_sum <= ip_checksum(checksum_sum, ip_hdr_src_ip_addr[31:16]);               
                  end   
                  5'd5: begin
                     m_tx_axis_tdata_reg <= {ip_hdr_flags, ip_hdr_frag_offset[12:8]};
                     checksum_sum <= ip_checksum(checksum_sum, ip_hdr_src_ip_addr[15:0]); 
                  end
                  5'd6: begin
                     m_tx_axis_tdata_reg <= ip_hdr_frag_offset[7:0];
                     checksum_sum <= ip_checksum(checksum_sum, ip_hdr_dst_ip_addr[31:16]);
                  end
                  5'd7: begin
                     m_tx_axis_tdata_reg <= ip_hdr_ttl;
                     checksum_sum <= ip_checksum(checksum_sum, ip_hdr_dst_ip_addr[15:0]);
                  end
                  5'd8: begin
                     m_tx_axis_tdata_reg <= ip_hdr_protocol;
                     ip_hdr_checksum <= ~checksum_sum;
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
assign s_ip_tx_hdr_rdy = s_ip_hdr_rdy_reg;
assign m_tx_axis_tdata = m_tx_axis_tdata_reg;
assign m_tx_axis_tvalid = m_tx_axis_tvalid_reg;
assign m_tx_axis_tlast = m_tx_axis_tlast_reg;

endmodule 