
`include "ip_pkg.sv"

interface ip_if
(
    input bit i_clk,
    input bit i_resetn    
);

    import ip_pkg::*;

    localparam SRC_MAC_ADDR = 48'h10_12_65_23_43_12;
    localparam DST_MAC_ADDR = 48'hFF_FF_FF_FF_FF_FF;
    localparam ETH_TYPE = 16'h0800;

    logic ip_tx_hdr_valid;                                       
    logic ip_tx_hdr_rdy;                                        
    logic [7:0]  ip_tx_hdr_type;                                     
    logic [15:0] ip_tx_total_length;                                
    logic [7:0]  ip_tx_protocol;                                  
    logic [31:0] ip_tx_src_ip_addr;                                
    logic [31:0] ip_tx_dst_ip_addr; 
    logic [47:0] eth_tx_src_mac_addr;
    logic [47:0] eth_tx_dst_mac_addr;
    logic [15:0] eth_tx_type;     
    
    logic s_eth_hdr_trdy;
    logic s_eth_hdr_tvalid;
    logic [47:0] m_eth_src_mac_addr;                               
    logic [47:0] m_eth_dst_mac_addr;                              
    logic [15:0] m_eth_type;         

   /* Methods */

    /* Drives the IP Header info to the the ip tx module */
    task drive_ip_hdr(ip_tx_hdr_t ip_hdr);
        ip_tx_hdr_valid <= 1'b1;
        ip_tx_hdr_type <= ip_hdr.tos;
        ip_tx_total_length <= ip_hdr.total_length;
        ip_tx_protocol <= ip_hdr.protocol; 
        ip_tx_src_ip_addr <= ip_hdr.src_ip_addr;
        ip_tx_dst_ip_addr <= ip_hdr.dst_ip_addr;
        //Drive MAC and eth type
        eth_tx_src_mac_addr <= SRC_MAC_ADDR;
        eth_tx_dst_mac_addr <= DST_MAC_ADDR;
        eth_tx_type <= ETH_TYPE;

        @(posedge i_clk);
        
        //Wait until the master indicates it is ready then lower the valid flag
        while(!ip_tx_hdr_rdy)
            @(posedge i_clk);

        ip_tx_hdr_valid <= 1'b0;
        
    endtask : drive_ip_hdr

    /* Task that drives ethernet header to the ip module. Used for ip rx */
    task drive_ethernet_hdr();
        // Dive ethernet header info
        s_eth_hdr_tvalid <= 1'b1;
        m_eth_src_mac_addr <= SRC_MAC_ADDR;
        m_eth_dst_mac_addr <= DST_MAC_ADDR;
        m_eth_type <= ETH_TYPE;  

        @(posedge i_clk);

        //Wait until the master indicates it is ready then lower the valid flag
        while(!ip_tx_hdr_rdy)
            @(posedge i_clk);

        ip_tx_hdr_valid <= 1'b0;           

    endtask : drive_ethernet_hdr

endinterface : ip_if