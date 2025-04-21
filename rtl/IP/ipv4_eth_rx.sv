`timescale 1ns / 1ps

/* This module is used to recieve packets directly from the ethernet MAC and de-encapsulate the 
 * Source & Destination MAC address & the ethernet type. It passes the ethernet header in parallel 
 * with the IP payload for the ip_rx to inspect/de-encapsulate.
 */

module ipv4_eth_rx
#(
    parameter AXI_STREAM_WIDTH = 8
)(
   input wire i_clk,
   input wire i_reset_n,

   /* AXI Stream Payload Inputs */
   input wire [AXI_STREAM_WIDTH-1:0] s_rx_axis_tdata,                  
   input wire s_rx_axis_tvalid,                                         
   input wire s_rx_axis_tlast,                                        
   output wire s_rx_axis_trdy,     

    /* AXI-Stream Payload Output */
    output wire [AXI_STREAM_WIDTH-1:0] m_rx_axis_tdata,
    output wire m_rx_axis_tvalid,
    output wire m_rx_axis_tlast,
    input wire m_rx_axis_trdy,                                        

    /* Ethernet Header Output */
    output wire m_eth_hdr_valid,
    input wire m_eth_hdr_rdy,
    output wire [47:0] m_eth_rx_src_mac_addr,
    output wire [47:0] m_eth_rx_dst_mac_addr,
    output wire [15:0] m_eth_rx_type   
);

/* State Machine Encoding */
localparam [1:0] IDLE = 2'b0;
localparam [1:0] ETHERNET_HEADER = 2'b01;
localparam [1:0] PAYLOAD = 2'b10;

/* Control Regs */
reg [3:0] hdr_cntr = 4'b0; 
reg [1:0] state = IDLE;

/* Data Path Registers */
reg [AXI_STREAM_WIDTH-1:0] m_rx_axis_tdata_reg;
reg m_rx_axis_tvalid_reg;                     
reg m_rx_axis_tlast_reg;                                          
reg s_rx_axis_trdy_reg;

reg m_eth_hdr_valid_reg = 1'b0;
reg [47:0] eth_src_mac_addr;
reg [47:0] eth_dst_mac_addr;
reg [15:0] eth_type;   

always @(posedge i_clk) begin
    if(!i_reset_n) begin
        hdr_cntr <= 4'b0;
    end else begin
        s_rx_axis_trdy_reg <= 1'b0;
        m_rx_axis_tvalid_reg <= 1'b0;
        m_eth_hdr_valid_reg <= 1'b0;

        case(state)
            IDLE: begin                
                hdr_cntr <= 4'b0;

                if(s_rx_axis_tvalid & m_eth_hdr_rdy & m_rx_axis_trdy) begin
                    s_rx_axis_trdy_reg <= 1'b1;
                    state <= ETHERNET_HEADER;
                end

            end 
            ETHERNET_HEADER: begin
                s_rx_axis_trdy_reg <= 1'b1;
                
                if(s_rx_axis_trdy_reg & s_rx_axis_tvalid) begin

                    hdr_cntr <= hdr_cntr + 1;

                    // Depending on the header counter, the input values will be associated with
                    // specific values of the ethernet header
                    if(hdr_cntr < 4'd6)
                        eth_src_mac_addr <= {eth_src_mac_addr[39:0], s_rx_axis_tdata};
                    else if(hdr_cntr < 4'd12)
                        eth_dst_mac_addr <= {eth_dst_mac_addr[39:0], s_rx_axis_tdata};
                    else if(hdr_cntr < 4'd14) begin
                        eth_type <= {eth_type[7:0], s_rx_axis_tdata};

                        if(hdr_cntr == 4'd13) begin
                            m_eth_hdr_valid_reg <= 1'b1;
                            state <= PAYLOAD;
                        end
                    end
                    
                end            

            end
            PAYLOAD: begin                
                m_rx_axis_tvalid_reg <= 1'b1;
                m_eth_hdr_valid_reg <= ~(m_eth_hdr_valid_reg & m_eth_hdr_rdy);

                if(s_rx_axis_trdy_reg & s_rx_axis_tvalid & m_rx_axis_trdy) begin
                    m_rx_axis_tdata_reg <= s_rx_axis_tdata;
                    m_rx_axis_tlast_reg <= s_rx_axis_tlast;

                    if(s_rx_axis_tlast & s_rx_axis_tvalid) begin
                        m_rx_axis_tvalid_reg <= 1'b0;
                        state <= IDLE;
                    end
                end
                

            end
        endcase
        
    end
end

/* Output Signals */
assign s_rx_axis_trdy = s_rx_axis_trdy_reg;
assign m_rx_axis_tdata = m_rx_axis_tdata_reg;
assign m_rx_axis_tvalid = m_rx_axis_tvalid_reg;
assign m_rx_axis_tlast = m_rx_axis_tlast_reg;

assign m_eth_hdr_valid = m_eth_hdr_valid_reg;
assign m_eth_rx_src_mac_addr = eth_src_mac_addr;
assign m_eth_rx_dst_mac_addr = eth_dst_mac_addr;
assign m_eth_rx_type = eth_type;

endmodule