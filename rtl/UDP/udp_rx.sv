`timescale 1ns / 1ps

/*
 * This module will recieve a fully encapsulated UDP packet from the IP layer, and will de-encapsulate
 * the packet before outputting the individual components of the UDP header in parallel with the 
 * UDP payload (Payload is output via AXI-Stream).
 * 
 * For reference, the UDP packet is as follows:
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

module udp_rx
#(
    parameter AXI_DATA_WIDTH = 8
)(
    input wire i_clk,
    input wire i_reset_n,

    /* Encapsulated UDP Input Payload - From IP*/
    input wire [AXI_DATA_WIDTH-1:0] s_rx_axis_tdata,
    input wire s_rx_axis_tvalid,
    input wire s_rx_axis_tlast,
    output wire s_rx_axis_trdy,

    /* AXI-Stream De-encapsulated Payload - Output Data */
    output wire [AXI_DATA_WIDTH-1:0] m_rx_axis_tdata,
    output wire m_rx_axis_tvalid,
    output wire m_rx_axis_tlast,
    input wire m_rx_axis_trdy,

    /* UDP Header Data */
    input wire m_udp_hdr_trdy,
    output wire m_udp_hdr_tvalid,
    output wire [15:0] m_udp_src_port,
    output wire [15:0] m_udp_dst_port,
    output wire [15:0] m_udp_length_port,
    output wire [15:0] m_udp_hdr_checksum
);

/* State Encoding */

localparam IDLE = 2'b00;
localparam UDP_HDR = 2'b01;
localparam UDP_PAYLOAD = 2'b10;

/* Data Path Regsiters */

reg [1:0] state = IDLE;
reg [3:0] hdr_cntr = 4'b0;
reg latched_hdr = 1'b0;

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

always @(posedge i_clk) begin
    if(!i_reset_n) begin
        state <= IDLE;
        hdr_cntr <= 4'b0;
        latched_hdr <= 1'b0;

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
        latched_hdr <= 1'b0;

        case(state)
            IDLE: begin
                hdr_cntr <= 4'b0;

                // If the up-stream module is ready to recieve UDP Header Fields & the
                // down-stream module contains valid data, we can begin the sampling process.
                if(m_udp_hdr_trdy & s_rx_axis_tvalid) begin
                    axis_trdy_reg <= 1'b1;
                    state <= UDP_HDR;
                end
            end 
            UDP_HDR: begin
                axis_trdy_reg <= 1'b1;

                // If the down-stream module has valid data, sample this data and store the initial
                // bytes in the UDP header registers.
                if(s_rx_axis_trdy & s_rx_axis_tvalid) begin

                    hdr_cntr <= hdr_cntr + 1;

                    case(hdr_cntr)
                        4'd0: udp_hdr_src_port_reg[15:8] <= s_rx_axis_tdata;
                        4'd1: udp_hdr_src_port_reg[7:0] <= s_rx_axis_tdata;
                        4'd2: udp_hdr_dst_port_reg[15:8] <= s_rx_axis_tdata;
                        4'd3: udp_hdr_dst_port_reg[7:0] <= s_rx_axis_tdata;
                        4'd4: udp_hdr_length[15:8] <= s_rx_axis_tdata;
                        4'd5: udp_hdr_length[7:0] <= s_rx_axis_tdata;
                        4'd6: udp_hdr_checksum_reg[15:8] <= s_rx_axis_tdata;
                        4'd7: begin
                            udp_hdr_checksum_reg[7:0] <= s_rx_axis_tdata;
                            udp_hdr_tvalid_reg <= 1'b1; 
                        end
                        4'd8: begin
                            // Latch the first payload data
                            axis_tdata_reg <= s_rx_axis_tdata;
                            axis_tvalid_reg <= s_rx_axis_tvalid;
                            axis_tlast_reg <= s_rx_axis_tlast;                                                                     

                            // Move to the payload state
                            state <= UDP_PAYLOAD;
                        end
                    endcase
                end
            end
            UDP_PAYLOAD: begin
                axis_trdy_reg <= 1'b1;
                axis_tvalid_reg <= 1'b1;
                udp_hdr_tvalid_reg <= 1'b1;

                if(latched_hdr || (m_udp_hdr_trdy & udp_hdr_tvalid_reg)) begin
                    udp_hdr_tvalid_reg <= 1'b0;
                    latched_hdr <= 1'b1;
                end

                // Before latching/driving the next payload byte, make sure the AXI handshake
                // is succesfull
                if(m_rx_axis_trdy & s_rx_axis_tvalid) begin
                    axis_tdata_reg <= s_rx_axis_tdata;
                    axis_tlast_reg <= s_rx_axis_tlast;  

                    // If it is the last byte within the packet, change states and lower trdy flag
                    if(s_rx_axis_tlast & axis_tvalid_reg) begin
                        axis_trdy_reg <= 1'b0;
                        state <= IDLE;
                    end      
                end

            end
        endcase
    end
end

/* Output Signals */

// AXI-Stream Master Output Signals 
assign m_rx_axis_tdata = axis_tdata_reg;
assign m_rx_axis_tvalid = axis_tvalid_reg;
assign m_rx_axis_tlast = axis_tlast_reg;

// AXI-Stream Slave Output Signals
assign s_rx_axis_trdy = (state == UDP_PAYLOAD) ? m_rx_axis_trdy : axis_trdy_reg;

// UDP Header Field Output Signals
assign m_udp_hdr_tvalid = udp_hdr_tvalid_reg;
assign m_udp_src_port = udp_hdr_src_port_reg;
assign m_udp_dst_port = udp_hdr_dst_port_reg;
assign m_udp_length_port = udp_hdr_length;
assign m_udp_hdr_checksum = udp_hdr_checksum_reg;


endmodule