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

typedef enum logic {
    UDP_HDR = 1'b0,
    UDP_PAYLOAD = 1'b1
} udp_state_t;

/* Data Path Regsiters */

udp_state_t state = UDP_HDR;
reg [2:0] hdr_cntr = 3'b0;
reg latched_hdr = 1'b0;

reg [AXI_DATA_WIDTH-1:0] m_axis_tdata_pipe = {AXI_DATA_WIDTH{1'b0}};
reg m_axis_tlast_pipe = 1'b0;
reg m_axis_tvalid_pipe = 1'b0;

reg [AXI_DATA_WIDTH-1:0] m_axis_tdata_reg = {AXI_DATA_WIDTH{1'b0}};
reg m_axis_tvalid_reg = 1'b0;
reg m_axis_tlast_reg = 1'b0;
reg s_axis_trdy_reg = 1'b0;

reg udp_hdr_tvalid_reg = 1'b0;
reg s_udp_hdr_trdy_reg = 1'b0; 
reg [15:0] udp_hdr_src_port_reg = 16'b0;
reg [15:0] udp_hdr_dst_port_reg = 16'b0;
reg [15:0] udp_hdr_checksum_reg = 16'b0;
reg [15:0] udp_hdr_length;

reg [63:0] udp_hdr = 64'b0; 

/* AXI-Stream Data Path */

always @(posedge i_clk) begin
    // Before latching/driving the next payload byte, make sure the AXI handshake
    // is succesfull
    if(m_rx_axis_trdy) begin
        if(m_axis_tvalid_pipe) begin
            m_axis_tdata_reg <= m_axis_tdata_pipe;
            m_axis_tlast_reg <= m_axis_tlast_pipe;  
            m_axis_tvalid_pipe <= 1'b0;                      
        end else begin
            m_axis_tdata_reg <= s_rx_axis_tdata;
            m_axis_tlast_reg <= s_rx_axis_tlast; 
        end    
    end

    //////////////////////////////////////////////////////////////////////////////////////
    // The s_rx_axis_trdy flag must be driven by the m_rx_axis_trdy flag. This is so 
    // the down-stream module and up-stream module can both be ready to recieve/send
    // data. Rather than passing the m_rx_axis_trdy flag combinationally to the down-stream
    // module (causing a possible critical path) the m_rx_axis_trdy value is stored in a 
    // register first. This leads to a 1cc delay between the m_rx_axis_trdy and s_rx_axis_trdy
    // flag which can lead to a single byte of data loss. To avoid this, when the m_rx_axis_trdy 
    // flag has lowered, and for the 1cc duration that teh s_rx_axis_trdy flag is raised,
    // the data is stored in a pipeline that is then used.
    ///////////////////////////////////////////////////////////////////////////////////////
    if(s_rx_axis_trdy & !m_rx_axis_trdy) begin
        m_axis_tdata_pipe <= s_rx_axis_tdata;
        m_axis_tlast_pipe <= s_rx_axis_tlast;
        m_axis_tvalid_pipe <= 1'b1;
    end
end

/* AXI-Stream Control Path */

always @(posedge i_clk) begin
    if(!i_reset_n) begin
        state <= UDP_HDR;
        hdr_cntr <= 3'b0;
        latched_hdr <= 1'b0;

        s_axis_trdy_reg <= 1'b0;
        m_axis_tvalid_reg <= 1'b0;
        udp_hdr_tvalid_reg <= 1'b0;
        s_udp_hdr_trdy_reg <= 1'b0;        
    end else begin
        s_axis_trdy_reg <= 1'b0;
        m_axis_tvalid_reg <= 1'b0;
        udp_hdr_tvalid_reg <= 1'b0;
        s_udp_hdr_trdy_reg <= 1'b0; 
        latched_hdr <= 1'b0;

        if(latched_hdr || (m_udp_hdr_trdy & udp_hdr_tvalid_reg)) begin
            udp_hdr_tvalid_reg <= 1'b0;
            latched_hdr <= 1'b1;
        end        

        case(state)
            UDP_HDR: begin
                s_axis_trdy_reg <= 1'b1;

                if(s_rx_axis_trdy & s_rx_axis_tvalid) begin
                    hdr_cntr <= hdr_cntr + 1;
                    udp_hdr <= {udp_hdr[55:0], s_rx_axis_tdata};
                end

                if(hdr_cntr == 3'd7) begin
                    hdr_cntr <= 3'b0;
                    state <= UDP_PAYLOAD;                    
                end
            end
            UDP_PAYLOAD: begin
                s_axis_trdy_reg <= m_rx_axis_trdy;
                m_axis_tvalid_reg <= 1'b1;
                udp_hdr_tvalid_reg <= 1'b1;     

                udp_hdr_src_port_reg <= udp_hdr[63:48];
                udp_hdr_dst_port_reg <= udp_hdr[47:32];
                udp_hdr_length <= udp_hdr[31:16];
                udp_hdr_checksum_reg <= udp_hdr[15:0];                             

                // If it is the last byte within the packet, change states and lower trdy flag
                if(s_rx_axis_tlast) begin
                    s_axis_trdy_reg <= 1'b0;
                    state <= UDP_HDR;
                end   
            end
        endcase
    end
end

/* Output Signals */

// AXI-Stream Master Output Signals 
assign m_rx_axis_tdata = m_axis_tdata_reg;
assign m_rx_axis_tvalid = m_axis_tvalid_reg;
assign m_rx_axis_tlast = m_axis_tlast_reg;

// AXI-Stream Slave Output Signals
assign s_rx_axis_trdy = s_axis_trdy_reg;

// UDP Header Field Output Signals
assign m_udp_hdr_tvalid = udp_hdr_tvalid_reg;
assign m_udp_src_port = udp_hdr_src_port_reg;
assign m_udp_dst_port = udp_hdr_dst_port_reg;
assign m_udp_length_port = udp_hdr_length;
assign m_udp_hdr_checksum = udp_hdr_checksum_reg;


endmodule