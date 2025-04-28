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
    input wire [15:0] s_udp_hdr_checksum,

    /* Input AXI-Stream Payload */
    input wire [AXI_DATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    input wire s_axis_tlast,
    output wire s_axis_trdy,

    /* AXI-Stream Output Data */
    output wire [AXI_DATA_WIDTH-1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    output wire m_axis_tlast,
    input wire m_axis_trdy
 );

localparam UDP_HDR_LENGTH = 16'h8;

/* State Declarations */

localparam IDLE = 2'b00;
localparam UDP_HDR = 2'b01;
localparam UDP_PAYLOAD = 2'b10;

/* Register Declarations */

reg [1:0] state = IDLE;
reg [3:0] hdr_cntr = 4'b0;

reg [AXI_DATA_WIDTH-1:0] axis_tdata_reg = {AXI_DATA_WIDTH{1'b0}};
reg axis_tvalid_reg = 1'b0;
reg axis_tlast_reg = 1'b0;
reg axis_trdy_reg = 1'b0;

reg udp_hdr_tvalid_reg = 1'b0;
reg s_udp_hdr_trdy_reg = 1'b0; 
reg [15:0] udp_hdr_src_port_reg = 16'b0;
reg [15:0] udp_hdr_dst_port_reg = 16'b0;
reg [15:0] udp_hdr_checksum_reg = 16'b0;
reg [15:0] udp_hdr_length;

// UDP Header length is always 8 bytes
assign udp_hdr_length = UDP_HDR_LENGTH;

always @(posedge i_clk) begin
    if(!i_reset_n) begin
        state <= IDLE;
        hdr_cntr <= 4'b0;

        axis_trdy_reg <= 1'b0;
        axis_tvalid_reg <= 1'b0;
        axis_tlast_reg <= 1'b0;
        udp_hdr_tvalid_reg <= 1'b0;
        s_udp_hdr_trdy_reg <= 1'b0; 

    end else begin
        axis_trdy_reg <= 1'b0;
        axis_tvalid_reg <= 1'b0;
        axis_tlast_reg <= 1'b0;
        udp_hdr_tvalid_reg <= 1'b0;
        s_udp_hdr_trdy_reg <= 1'b0; 

        case(state)
            IDLE: begin
                hdr_cntr <= 4'b0;
                s_udp_hdr_trdy_reg <= 1'b1;

                if(s_udp_hdr_tvalid & s_udp_hdr_trdy_reg & s_axis_tvalid) begin
                    // Latch the UDP Input Header Data
                    udp_hdr_src_port_reg <= s_udp_src_port;
                    udp_hdr_dst_port_reg <= s_udp_dst_port;
                    udp_hdr_checksum_reg <= s_udp_hdr_checksum;
                    s_udp_hdr_trdy_reg <= 1'b0;
                    
                    // Set the first byte to transmit as the source port
                    axis_tdata_reg <= s_udp_src_port[15:8];
                    axis_tvalid_reg <= 1'b1;

                    // Shift states & increment the header counter
                    hdr_cntr <= hdr_cntr + 1;
                    state <= UDP_HDR;
                end
            end 
            UDP_HDR: begin
                axis_tvalid_reg <= 1'b1;
                // Before sending more data, make sure the downstream module is ready
                if(m_axis_trdy) begin

                    hdr_cntr <= hdr_cntr + 1;

                    // Iterate through the header counter to determine which part of teh header to transmit
                    case(hdr_cntr)
                        5'd1: axis_tdata_reg <= udp_hdr_src_port_reg[7:0];
                        5'd2: axis_tdata_reg <= udp_hdr_dst_port_reg[15:8];
                        5'd3: axis_tdata_reg <= udp_hdr_dst_port_reg[7:0];
                        5'd4: axis_tdata_reg <= udp_hdr_length[15:8];
                        5'd5: axis_tdata_reg <= udp_hdr_length[7:0];
                        5'd6: axis_tdata_reg <= udp_hdr_checksum_reg[15:8];
                        5'd7: begin
                            axis_tdata_reg <= udp_hdr_checksum_reg[7:0];
                            axis_trdy_reg <= 1'b1;

                            state <= UDP_PAYLOAD;
                        end
                    endcase
                end
            end 
            UDP_PAYLOAD: begin
                axis_tvalid_reg <= 1'b1;
                axis_trdy_reg <= 1'b1;

                if(s_axis_tvalid & m_axis_trdy) begin
                    axis_tdata_reg <= s_axis_tdata;
                    axis_tlast_reg <= s_axis_tlast;

                    if(s_axis_tlast & axis_tvalid_reg) begin
                        axis_trdy_reg <= 1'b0;
                        state <= IDLE;
                    end
                end
            end
        endcase
    end
end

/* Output Logic */
assign s_udp_hdr_trdy = s_udp_hdr_trdy_reg;
assign s_axis_trdy = (state == UDP_PAYLOAD) ? m_axis_trdy : axis_trdy_reg;
assign m_axis_tdata = axis_tdata_reg;
assign m_axis_tvalid = axis_tvalid_reg;
assign m_axis_tlast = axis_tlast_reg;

endmodule