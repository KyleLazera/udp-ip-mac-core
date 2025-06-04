`timescale 1ns / 1ps

/*
 * This module takes in UDP header information in parallel with a payload via AXI-Stream
 * to encapsulate within a UDP header, and then outputs the data as an encapsulated 
 * packet via AXI-Stream.
 * 
 *  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 *  +---------------+---------------+---------------+---------------+
 *  |           Source Port         |      Destination Port         |
 *  +---------------+---------------+---------------+---------------+
 *  |         UDP Length            |          UDP Checksum         |
 *  +---------------+---------------+---------------+---------------+
 *  |                           Payload                             |
 *  +---------------+---------------+---------------+---------------+
 * 
 * Similarly to the IP Module, the UDP module also requires the total size of the payload
 * (including the UDP header). Rather than buffering the data first to calculate the size,
 * this module counts the total number of bytes in line with the payload, and outputs the 
 * calculated checksum & length fields in parallel. These values are then recieved by the 
 * ethernet MAC and inserted into the correct location of the network packet. This ensures 
 * the TX data path for the UDP module only induces 1 clock cycle delay.
 */

 module udp_tx
 #(
    parameter AXI_DATA_WIDTH = 8
 )(
    input wire i_clk,
    input wire i_reset_n,

    /* UDP Header Port Fields */
    output wire s_udp_hdr_trdy,
    input wire s_udp_hdr_tvalid,
    input wire [15:0] s_udp_src_port,
    input wire [15:0] s_udp_dst_port,

    /* Input AXI-Stream Payload */
    input wire [AXI_DATA_WIDTH-1:0] s_tx_axis_tdata,
    input wire s_tx_axis_tvalid,
    input wire s_tx_axis_tlast,
    output wire s_tx_axis_trdy,

    /* AXI-Stream Output Data */
    output wire [AXI_DATA_WIDTH-1:0] m_tx_axis_tdata,
    output wire m_tx_axis_tvalid,
    output wire m_tx_axis_tlast,
    input wire m_tx_axis_trdy
 );

localparam logic [15:0] UDP_CHECKSUM_PLACEHOLDER = 16'hDEAD;
localparam logic [15:0] UDP_LENGTH_PLACHOLDER = 16'hBEEF;

/* State Declarations */

localparam IDLE = 2'b00;
localparam UDP_HDR = 2'b01;
localparam UDP_PAYLOAD = 2'b10;

/* Register Declarations */

reg [1:0] state = IDLE;
reg [3:0] hdr_cntr = 4'b0;

reg [AXI_DATA_WIDTH-1:0] s_axis_tdata_reg = {AXI_DATA_WIDTH{1'b0}};
reg s_axis_tvalid_reg = 1'b0;
reg s_axis_tlast_reg = 1'b0;
reg s_axis_trdy_reg = 1'b0;

reg udp_hdr_tvalid_reg = 1'b0;
reg s_udp_hdr_trdy_reg = 1'b0; 
reg [AXI_DATA_WIDTH-1:0] udp_header_bytes [0:6];

/* Data Path Pipeline Logic */
always @(posedge i_clk) begin
    s_axis_tvalid_reg <= s_tx_axis_tvalid;
    s_axis_tlast_reg <= s_tx_axis_tlast;
    udp_hdr_tvalid_reg <= s_udp_hdr_tvalid; 
end

/* FSM Control Path Logic */
always @(posedge i_clk) begin
    if(!i_reset_n) begin
        state <= IDLE;
        hdr_cntr <= 4'b0;
    end else begin
        s_axis_trdy_reg <= 1'b0;        
        s_udp_hdr_trdy_reg <= 1'b0;        
        hdr_cntr <= 4'b0;

        case(state)
            IDLE: begin                
                s_udp_hdr_trdy_reg <= 1'b1;
                // Set the first byte to transmit as the source port
                s_axis_tdata_reg <= s_udp_src_port[15:8];

                if(udp_hdr_tvalid_reg) begin
                    // Latch the UDP Input Header Data
                    udp_header_bytes[0] <= s_udp_src_port[7:0];
                    udp_header_bytes[1] <= s_udp_dst_port[15:8];
                    udp_header_bytes[2] <= s_udp_dst_port[7:0];   
                    udp_header_bytes[3] <= UDP_LENGTH_PLACHOLDER[15:8];
                    udp_header_bytes[4] <= UDP_LENGTH_PLACHOLDER[7:0];
                    udp_header_bytes[5] <= UDP_CHECKSUM_PLACEHOLDER[15:8];
                    udp_header_bytes[6] <= UDP_CHECKSUM_PLACEHOLDER[7:0];                                     
                    
                    s_udp_hdr_trdy_reg <= 1'b0;

                    // Shift states
                    state <= UDP_HDR;
                end
            end 
            UDP_HDR: begin
                // Before sending the initial UDP header, make sure the downstream module is ready
                // to recieve data 
                if(m_tx_axis_trdy) begin

                    hdr_cntr <= hdr_cntr + 1;

                    // Iterate and transmit each byte of teh UDP header
                    s_axis_tdata_reg <= udp_header_bytes[hdr_cntr];

                    if(hdr_cntr == 5'd6) begin
                        s_axis_trdy_reg <= m_tx_axis_trdy;
                        state <= UDP_PAYLOAD;                        
                    end
                end
            end 
            UDP_PAYLOAD: begin
                s_axis_trdy_reg <= m_tx_axis_trdy;

                // AXI-Stream Handhsaking is valid before transmitting data tot eh donw-stream
                // module
                if(m_tx_axis_trdy) begin
                    s_axis_tdata_reg <= s_tx_axis_tdata;

                    // If the tlast signal is asserted, this indicates we have recieved the last beat
                    // of teh transaction and we should therefore lower the rdy flag & return to the 
                    // IDLE state
                    if(s_tx_axis_tlast) begin
                        s_axis_trdy_reg <= 1'b0;
                        state <= IDLE;
                    end
                end
            end
        endcase
    end
end

/* Output Logic */

assign s_udp_hdr_trdy = s_udp_hdr_trdy_reg;
assign s_tx_axis_trdy = s_axis_trdy_reg;

// Master AXI-Stream Outputs
assign m_tx_axis_tdata = s_axis_tdata_reg;
assign m_tx_axis_tvalid = s_axis_tvalid_reg;
assign m_tx_axis_tlast = s_axis_tlast_reg;

endmodule