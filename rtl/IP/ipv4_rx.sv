
/* This module recieves ethernet payload data as well as ethernet header data
 * in parallel with one another. It passes through the ethernet headers, and inspects
 * the IP payload to determine if the packet is good or bad. This module checks for 
 * the following things:
 *  1) IP Payload size = total length field 
 *  2) Checksum field is recalculated based on recieved inputs to see if there is a match
 *  3) IP Version = IPv4
 *  4) Checks the ether type is valid (ARP or IPv4)
 * 
 * For reference, the IP frame is below:
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
 */

module ipv4_rx
#(
    parameter AXI_DATA_WIDTH = 8    
)(
    input wire i_clk,
    input wire i_reset_n,

    /* Ethernet Header Input */
    input wire s_eth_hdr_valid,
    output wire s_eth_hdr_rdy,
    input wire [47:0] s_eth_rx_src_mac_addr,
    input wire [47:0] s_eth_rx_dst_mac_addr,
    input wire [15:0] s_eth_rx_type,

    /* Ethernet Frame Input */
    input wire [AXI_DATA_WIDTH-1:0] s_rx_axis_tdata,
    input wire s_rx_axis_tvalid,
    input wire s_rx_axis_tlast,
    output wire s_rx_axis_trdy,

    /* IP/Ethernet Frame Outputs */
    input wire m_ip_hdr_trdy,
    output wire m_ip_hdr_tvalid,
    output wire [31:0] m_ip_rx_src_ip_addr,
    output wire [31:0] m_ip_rx_dst_ip_addr,
    output wire [47:0] m_eth_rx_src_mac_addr,
    output wire [47:0] m_eth_rx_dst_mac_addr,
    output wire [15:0] m_eth_rx_type,    

    /* IP Frame Payload */
    output wire [AXI_DATA_WIDTH-1:0] m_rx_axis_tdata,
    output wire m_rx_axis_tvalid,
    output wire m_rx_axis_tlast,
    input wire m_rx_axis_trdy,

    /* Status Flags */
    output wire bad_packet     
);

/* Constant Params */
localparam IPV4_VERSION = 4'd4; 

/* State Encoding */
localparam [1:0] IDLE = 2'b0;
localparam [1:0] HEADER_CHECK = 2'b01;
localparam [1:0] PAYLOAD = 2'b10;
localparam [1:0] WAIT = 2'b11;

/* Data Path Registers */
reg [1:0] state = IDLE;
reg [15:0] ip_checksum_fields;
reg [AXI_DATA_WIDTH-1:0] m_rx_axis_tdata_reg = {AXI_DATA_WIDTH-1{1'b0}};
reg m_rx_axis_tvalid_reg = 1'b0;
reg m_rx_axis_tlast_reg = 1'b0;
reg s_rx_axis_trdy_reg = 1'b0;
reg bad_pckt_reg = 1'b0;

reg [4:0] hdr_cntr = 5'b0;
reg latched_hdr = 1'b0;

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

/* Ethernet Header Data Path Registers */
reg eth_hdr_rdy_reg = 1'b0;
reg [47:0] eth_rx_src_mac_addr = 48'd0;
reg [47:0] eth_rx_dst_mac_addr = 48'd0;
reg [15:0] eth_rx_type = 16'd0;

/* IP Header Data Path Registers */
reg m_ip_hdr_tvalid_reg = 1'b0;
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

/* De-encapsulation Logic */
always @(posedge i_clk) begin
    if(!i_reset_n) begin
        state <= IDLE;

        eth_hdr_rdy_reg <= 1'b0;
        m_ip_hdr_tvalid_reg <= 1'b0;
        s_rx_axis_trdy_reg <= 1'b0;
        m_rx_axis_tvalid_reg <= 1'b0;

        bad_pckt_reg <= 1'b0;
        latched_hdr <= 1'b0;
        hdr_cntr <= 5'b0;
        checksum_sum <= 16'b0;
    end else begin
        // Default Values
        eth_hdr_rdy_reg <= 1'b0;
        bad_pckt_reg <= 1'b0;
        s_rx_axis_trdy_reg <= 1'b0;
        m_rx_axis_tvalid_reg <= 1'b0;
        m_ip_hdr_tvalid_reg <= 1'b0;

        case(state)
        IDLE: begin

            if(latched_hdr || s_eth_hdr_valid & eth_hdr_rdy_reg)
                eth_hdr_rdy_reg <= 1'b0;
            else
                eth_hdr_rdy_reg <= 1'b1;


            // Ethernet header handshake - Latch the ethernet header
            if(eth_hdr_rdy_reg & s_eth_hdr_valid) begin
                eth_rx_src_mac_addr <= s_eth_rx_src_mac_addr;
                eth_rx_dst_mac_addr <= s_eth_rx_dst_mac_addr;
                eth_rx_type <= s_eth_rx_type;

                //Assert the latched_hdr flag
                latched_hdr <= 1'b1;
            end

            // If we have latched header data and both the up-stream and down-stream modules
            // are ready to recieve/send data, begin the state machine.
            if(latched_hdr & s_rx_axis_tvalid & m_rx_axis_trdy) begin
                latched_hdr <= 1'b0;
                s_rx_axis_trdy_reg <= 1'b1;
                checksum_sum <= 16'b0;
                hdr_cntr <= 5'b0;
                state <= HEADER_CHECK;
            end
        end
        HEADER_CHECK: begin
            s_rx_axis_trdy_reg <= 1'b1;

            if(s_rx_axis_trdy_reg & s_rx_axis_tvalid) begin

                // Pass the 16 bit field into the checksum on every 2nd cntr iteration
                if(hdr_cntr[0] == 1'b0)
                    ip_checksum_fields <= {ip_checksum_fields[7:0], s_rx_axis_tdata};
                else 
                    checksum_sum <= ip_checksum(checksum_sum, {ip_checksum_fields[7:0], s_rx_axis_tdata});

                // Iterate through each byte of the IP header and store the values in the data registers
                case(hdr_cntr)
                    5'd0: begin
                        // Make sure the packet is an IPv4 packet
                        if(s_rx_axis_tdata[7:4] == IPV4_VERSION) begin
                            ip_hdr_length <= s_rx_axis_tdata[3:0];
                            ip_hdr_version <= s_rx_axis_tdata[7:4];
                        end else
                            state <= WAIT;
                    end
                    5'd1: ip_hdr_type <= s_rx_axis_tdata;
                    5'd2: ip_hdr_total_length[15:8] <= s_rx_axis_tdata;
                    5'd3: ip_hdr_total_length[7:0] <= s_rx_axis_tdata;
                    5'd4: ip_hdr_id[15:8] <= s_rx_axis_tdata;
                    5'd5: ip_hdr_id[7:0] <= s_rx_axis_tdata;
                    5'd6: begin
                        ip_hdr_flags <= s_rx_axis_tdata[7:5];
                        ip_hdr_frag_offset[12:8] <= s_rx_axis_tdata[4:0];
                        // Subtract the total length register from the number of header bytes
                        ip_hdr_total_length <= ip_hdr_total_length - (ip_hdr_length << 2); 
                    end
                    5'd7: ip_hdr_frag_offset[7:0] <= s_rx_axis_tdata;
                    5'd8: ip_hdr_ttl <= s_rx_axis_tdata;
                    5'd9: ip_hdr_protocol <= s_rx_axis_tdata;
                    5'd10: ip_hdr_checksum[15:8] <= s_rx_axis_tdata;
                    5'd11: ip_hdr_checksum[7:0] <= s_rx_axis_tdata;
                    5'd12: ip_hdr_src_ip_addr[31:24] <= s_rx_axis_tdata;
                    5'd13: ip_hdr_src_ip_addr[23:16] <= s_rx_axis_tdata;
                    5'd14: ip_hdr_src_ip_addr[15:8] <= s_rx_axis_tdata;
                    5'd15: ip_hdr_src_ip_addr[7:0] <= s_rx_axis_tdata;    
                    5'd16: ip_hdr_dst_ip_addr[31:24] <= s_rx_axis_tdata;
                    5'd17: ip_hdr_dst_ip_addr[23:16] <= s_rx_axis_tdata;
                    5'd18: ip_hdr_dst_ip_addr[15:8] <= s_rx_axis_tdata;
                    5'd19: ip_hdr_dst_ip_addr[7:0] <= s_rx_axis_tdata;   
                    5'd20: begin
                        // Make sure the checksum is correct 
                        if(checksum_sum == 16'hffff) begin
                            s_rx_axis_trdy_reg <= m_rx_axis_trdy & s_rx_axis_tvalid;
                            m_ip_hdr_tvalid_reg <= 1'b1;

                            //Store the first raw payload data
                            m_rx_axis_tdata_reg <= s_rx_axis_tdata;
                            m_rx_axis_tvalid_reg <= s_rx_axis_tvalid;
                            m_rx_axis_tlast_reg <= s_rx_axis_tlast;  
                            // Decrement the payload byte counter
                            ip_hdr_total_length <= ip_hdr_total_length - 1'b1;  

                            if(s_rx_axis_tlast & s_rx_axis_tvalid)
                                state <= IDLE;                     

                            state <= PAYLOAD;                             
                        end else begin
                            bad_pckt_reg <= 1'b1;
                            state <= WAIT;
                        end
                    end                                    
                endcase            

                hdr_cntr <= hdr_cntr + 1'b1;
            end
        end
        PAYLOAD: begin
            s_rx_axis_trdy_reg <= 1'b1;
            m_rx_axis_tvalid_reg <= 1'b1;
            m_ip_hdr_tvalid_reg <= 1'b1;

            // If the up-stream module & down-stream module have data/can recieve data
            // we can latch the incoming data
            if(m_rx_axis_trdy & s_rx_axis_tvalid) begin
                m_rx_axis_tdata_reg <= s_rx_axis_tdata;
                m_rx_axis_tvalid_reg <= s_rx_axis_tvalid;
                m_rx_axis_tlast_reg <= s_rx_axis_tlast;

                // Count the number of bytes recieved
                ip_hdr_total_length <= ip_hdr_total_length - 1'b1;

                if(s_rx_axis_tlast & s_rx_axis_tvalid) begin
                    
                    // Total bytes in the payload did not match the bytes specified in the IP Header
                    if(ip_hdr_total_length != 16'b0)begin
                        bad_pckt_reg <= 1'b1;
                        state <= IDLE;
                    end

                    s_rx_axis_trdy_reg <= 1'b0;
                    state <= IDLE;
                end
            end

        end
        WAIT: begin
            s_rx_axis_trdy_reg <= 1'b1;
            // Wait until the remainder of the packet has been recieved
            if(s_rx_axis_tlast & s_rx_axis_tvalid) begin
                s_rx_axis_trdy_reg <= 1'b0;
                state <= IDLE;
            end
        end
        endcase
    end
end

/* Output Modules */
assign s_eth_hdr_rdy = eth_hdr_rdy_reg;
assign s_rx_axis_trdy = s_rx_axis_trdy_reg;
assign m_rx_axis_tvalid = m_rx_axis_tvalid_reg;
assign m_rx_axis_tdata = m_rx_axis_tdata_reg;
assign m_rx_axis_tlast = m_rx_axis_tlast_reg;

assign bad_packet = bad_pckt_reg;

/* Output Ethernet/IP Header Info */
assign m_ip_hdr_tvalid = m_ip_hdr_tvalid_reg;
assign m_ip_rx_src_ip_addr = ip_hdr_src_ip_addr;
assign m_ip_rx_dst_ip_addr = ip_hdr_dst_ip_addr;
assign m_eth_rx_src_mac_addr = eth_rx_src_mac_addr;
assign m_eth_rx_dst_mac_addr = eth_rx_dst_mac_addr;
assign m_eth_rx_type = eth_rx_type;

endmodule