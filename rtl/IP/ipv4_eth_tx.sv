`timescale 1ns / 1ps

/* This module takes in an IP packet and encapsulates it within the ethernet formatting as shown below:
 *  _____________________________________________________________________________________________ 
 *  |                      |                      |                      |                      |                
 *  |     Src MAC Addr     |     Dst MAC Addr     |      Eth Type        |      IP Packet       |                
 *  |______________________|______________________|______________________|______________________|    
 * 
 * The packet is then output via AXI-Stream in a format that can be directly passed to an ethernet MAC.
 */           

module ipv4_eth_tx
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

   /* Ethernet Header Inputs */
   input wire s_eth_tx_hdr_valid,                                        // Indicates the header inputs are valid
   output wire s_eth_tx_hdr_rdy,                                         // IP tx is ready for next header inputs   
   input wire [47:0] s_eth_tx_src_mac_addr,                             // Eth source mac address
   input wire [47:0] s_eth_tx_dst_mac_addr,                             // Eth destination mac address   
   input wire [15:0] s_eth_tx_type,                                     // Eth type     

   /* AXI Stream Packaged IP Outputs */
   output wire [AXI_STREAM_WIDTH-1:0] m_tx_axis_tdata,                  // Packaged IP data (header & payload)
   output wire m_tx_axis_tvalid,                                        // valid signal for tdata
   output wire m_tx_axis_tlast,                                         // last byte of IP package
   input wire m_tx_axis_trdy                                            // Back pressure from downstream module indciating it is ready   
);

/* State Machine Encoding */
localparam [1:0] IDLE = 2'b0;
localparam [1:0] ETHERNET_HEADER = 2'b01;
localparam [1:0] PAYLOAD = 2'b10;

/* Control Regs */
reg [1:0] state = IDLE;
reg [3:0] hdr_cntr = 4'b0; 

/* Data Path Registers */
reg [AXI_STREAM_WIDTH-1:0] m_tx_axis_tdata_reg;
reg m_tx_axis_tvalid_reg;                     
reg m_tx_axis_tlast_reg;                                          
reg s_tx_axis_trdy_reg;

reg s_eth_tx_hdr_rdy_reg = 1'b0;
reg [47:0] eth_src_mac_addr;
reg [47:0] eth_dst_mac_addr;
reg [15:0] eth_type;   

always @(posedge i_clk) begin
    if(!i_reset_n) begin
        state <= IDLE;
        hdr_cntr <= 4'b0;
        /* Data Path Resets */
        m_tx_axis_tdata_reg <= {AXI_STREAM_WIDTH{1'b0}};
        m_tx_axis_tvalid_reg <= 1'b0;
        m_tx_axis_tlast_reg <= 1'b0; 
        s_tx_axis_trdy_reg <= 1'b0;  
        s_eth_tx_hdr_rdy_reg <= 1'b0;         
    end else begin
        s_eth_tx_hdr_rdy_reg <= 1'b0;
        s_tx_axis_trdy_reg <= 1'b0;
        m_tx_axis_tvalid_reg <= 1'b0;
        m_tx_axis_tlast_reg <= 1'b0;

        case(state)
            IDLE: begin
                s_eth_tx_hdr_rdy_reg <= 1'b1;
                hdr_cntr <= 4'b0;

                // If ethernet header handshake is succesfull & the up-stream module contains valid data,
                // sample the ethernet header and begin the transmission process
                if(s_eth_tx_hdr_rdy_reg & s_eth_tx_hdr_valid & s_tx_axis_tvalid) begin
                    eth_src_mac_addr <= s_eth_tx_src_mac_addr;
                    eth_dst_mac_addr <= s_eth_tx_dst_mac_addr;
                    eth_type <= s_eth_tx_type;

                    s_eth_tx_hdr_rdy_reg <= 1'b0;
                    //m_tx_axis_tvalid_reg <= 1'b1;
                    state <= ETHERNET_HEADER;
                end
            end 
            ETHERNET_HEADER: begin
                m_tx_axis_tvalid_reg <= 1'b1;

                // Transmit the Ethernet header first if down-stream module is ready
                if(m_tx_axis_trdy) begin

                    hdr_cntr <= hdr_cntr + 1;

                    case(hdr_cntr)
                        4'd0: m_tx_axis_tdata_reg <= eth_src_mac_addr[47:40];
                        4'd1: m_tx_axis_tdata_reg <= eth_src_mac_addr[39:32];
                        4'd2: m_tx_axis_tdata_reg <= eth_src_mac_addr[31:24];
                        4'd3: m_tx_axis_tdata_reg <= eth_src_mac_addr[23:16];  
                        4'd4: m_tx_axis_tdata_reg <= eth_src_mac_addr[15:8];
                        4'd5: m_tx_axis_tdata_reg <= eth_src_mac_addr[7:0];      
                        4'd6: m_tx_axis_tdata_reg <= eth_dst_mac_addr[47:40];
                        4'd7: m_tx_axis_tdata_reg <= eth_dst_mac_addr[39:32];
                        4'd8: m_tx_axis_tdata_reg <= eth_dst_mac_addr[31:24];
                        4'd9: m_tx_axis_tdata_reg <= eth_dst_mac_addr[23:16];  
                        4'd10: m_tx_axis_tdata_reg <= eth_dst_mac_addr[15:8];
                        4'd11: m_tx_axis_tdata_reg <= eth_dst_mac_addr[7:0];  
                        4'd12: m_tx_axis_tdata_reg <= eth_type[15:8];
                        4'd13: begin
                            m_tx_axis_tdata_reg <= eth_type[7:0];       
                            s_tx_axis_trdy_reg <= 1'b1;
                            state <= PAYLOAD;
                        end                                                                                    
                    endcase
                end
            end
            PAYLOAD: begin
                m_tx_axis_tvalid_reg <= 1'b1;
                s_tx_axis_trdy_reg <= 1'b1;

                // If teh up-stream and downstream modules are ready/have valid data, store the 
                // AXI-Stream input
                if(m_tx_axis_tvalid_reg & m_tx_axis_trdy & s_tx_axis_tvalid) begin
                    m_tx_axis_tdata_reg <= s_tx_axis_tdata;
                    m_tx_axis_tvalid_reg <= s_tx_axis_tvalid;
                    m_tx_axis_tlast_reg <= s_tx_axis_tlast; 

                    if(s_tx_axis_tvalid & s_tx_axis_tlast) begin                        
                        m_tx_axis_tvalid_reg <= 1'b0;
                        s_tx_axis_trdy_reg <= 1'b0;
                        state <= IDLE;
                    end                     
                end
            end
        endcase
    end
end

/* AXI-Stream IP Frame Output */
assign m_tx_axis_tdata = m_tx_axis_tdata_reg;
assign m_tx_axis_tvalid = m_tx_axis_tvalid_reg;
assign m_tx_axis_tlast = m_tx_axis_tlast_reg;
assign s_tx_axis_trdy = s_tx_axis_trdy_reg;

/* Ethernet Handhsake outputs */
assign s_eth_tx_hdr_rdy = s_eth_tx_hdr_rdy_reg;

endmodule : ipv4_eth_tx

