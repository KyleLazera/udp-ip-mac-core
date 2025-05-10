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

reg [AXI_DATA_WIDTH-1:0] axis_tdata_reg = {AXI_DATA_WIDTH{1'b0}};
reg axis_tvalid_reg = 1'b0;
reg axis_tlast_reg = 1'b0;
reg axis_trdy_reg = 1'b0;

reg udp_hdr_tvalid_reg = 1'b0;
reg s_udp_hdr_trdy_reg = 1'b0; 
reg [15:0] udp_hdr_src_port_reg = 16'b0;
reg [15:0] udp_hdr_dst_port_reg = 16'b0;

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

                if(s_udp_hdr_tvalid & s_udp_hdr_trdy_reg) begin
                    // Latch the UDP Input Header Data
                    udp_hdr_src_port_reg <= s_udp_src_port;
                    udp_hdr_dst_port_reg <= s_udp_dst_port;
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
                if(m_tx_axis_trdy & m_tx_axis_tvalid) begin

                    hdr_cntr <= hdr_cntr + 1;

                    // Iterate through the header counter to determine which part of teh header to transmit
                    case(hdr_cntr)
                        5'd1: axis_tdata_reg <= udp_hdr_src_port_reg[7:0];
                        5'd2: axis_tdata_reg <= udp_hdr_dst_port_reg[15:8];
                        5'd3: axis_tdata_reg <= udp_hdr_dst_port_reg[7:0];
                        5'd4: axis_tdata_reg <= UDP_LENGTH_PLACHOLDER[15:8];
                        5'd5: axis_tdata_reg <= UDP_LENGTH_PLACHOLDER[7:0];
                        5'd6: axis_tdata_reg <= UDP_CHECKSUM_PLACEHOLDER[15:8];
                        5'd7: begin
                            axis_tdata_reg <= UDP_CHECKSUM_PLACEHOLDER[7:0];
                            axis_trdy_reg <= 1'b1;

                            state <= UDP_PAYLOAD;
                        end
                    endcase
                end
            end 
            UDP_PAYLOAD: begin
                axis_tvalid_reg <= 1'b1;
                axis_trdy_reg <= 1'b1;

                if(s_tx_axis_tvalid & m_tx_axis_trdy) begin
                    axis_tdata_reg <= s_tx_axis_tdata;
                    axis_tlast_reg <= s_tx_axis_tlast;

                    if(s_tx_axis_tlast & axis_tvalid_reg) begin
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
assign s_tx_axis_trdy = (state == UDP_PAYLOAD) ? m_tx_axis_trdy : axis_trdy_reg;

// Master AXI-Stream Outputs
assign m_tx_axis_tdata = axis_tdata_reg;
assign m_tx_axis_tvalid = axis_tvalid_reg;
assign m_tx_axis_tlast = axis_tlast_reg;

endmodule