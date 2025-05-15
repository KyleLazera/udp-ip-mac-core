`include "ip_pkg.sv"
`include "../../common/axi_stream_rx_bfm.sv"
`include "../../common/axi_stream_tx_bfm.sv"

interface ip_rx_if
(
    input bit i_clk,
    input bit i_resetn 
);

    import ip_pkg::*;

    // Instantiate AXI-Stream Interface
    axi_stream_tx_bfm axi_tx(.s_aclk(i_clk), .s_sresetn(i_resetn));
    axi_stream_rx_bfm axi_rx(.m_aclk(i_clk), .m_sresetn(i_resetn));

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

    /* Rx IP/Ethernet Header Data */
    logic eth_rx_hdr_trdy;
    logic eth_rx_hdr_tvalid;
    logic [47:0] eth_rx_src_mac_addr;                               
    logic [47:0] eth_rx_dst_mac_addr;   
    logic [31:0] ip_rx_src_ip_addr;                                
    logic [31:0] ip_rx_dst_ip_addr;                               
    logic [15:0] eth_rx_type; 
    logic bad_packet; 

    /* Drives Ethernet Header info to the RX IP Module - Used when ETH_FRAME = 0 */
    task drive_ethernet_hdr(eth_hdr_t eth_hdr);
        // Dive ethernet header info
        ip_tx_hdr_valid <= 1'b1;
        eth_tx_src_mac_addr <= eth_hdr.src_mac_addr;
        eth_tx_dst_mac_addr <= eth_hdr.dst_mac_addr;
        eth_tx_type <= eth_hdr.eth_type;

        @(posedge i_clk);

        //Wait until the master indicates it is ready then lower the valid flag
        while(!ip_tx_hdr_rdy)
            @(posedge i_clk);

        ip_tx_hdr_valid <= 1'b0;           

    endtask : drive_ethernet_hdr

    /* Sample the output Ethernet & IP Header fields */
    task read_pckt_header(ref ip_pckt_t rx_ip_pckt);
        // Raise the trdy flag
        eth_rx_hdr_trdy <= 1'b1;
        @(posedge i_clk);

        // If the tvalid flag is not asserted, wait until it is
        while(!eth_rx_hdr_tvalid)
            @(posedge i_clk);

        if(eth_rx_hdr_trdy & eth_rx_hdr_tvalid) begin
            rx_ip_pckt.eth_hdr.src_mac_addr = eth_rx_src_mac_addr;
            rx_ip_pckt.eth_hdr.dst_mac_addr = eth_rx_dst_mac_addr;
            rx_ip_pckt.eth_hdr.eth_type = eth_rx_type;
            rx_ip_pckt.ip_hdr.src_ip_addr = ip_rx_src_ip_addr;
            rx_ip_pckt.ip_hdr.dst_ip_addr = ip_rx_dst_ip_addr;
        end

        // Lower the ready flag
        eth_rx_hdr_trdy <= 1'b0;
        @(posedge i_clk);

    endtask : read_pckt_header

    /* Task used to drive ethernet packets to the ip rx module */
    task drive_eth_packet(ip_pckt_t ip_packet);
        fork
            drive_ethernet_hdr(ip_packet.eth_hdr);
            axi_tx.axis_transmit_basic(ip_packet.payload, 1'b1, 1'b1);
        join
    endtask : drive_eth_packet

    /* Task used to sample the output of IP RX*/
    task read_raw_packet(ref ip_pckt_t rx_ip_pckt);
        bit [7:0] rx_data[$];       
        
        fork
            begin
                axi_rx.axis_read(rx_data);
            end
            begin
                read_pckt_header(rx_ip_pckt);
            end
        join

        rx_ip_pckt.payload.delete();

        foreach(rx_data[i]) begin
            rx_ip_pckt.payload[i] = rx_data[i];
        end

        rx_data.delete();

    endtask : read_raw_packet

endinterface : ip_rx_if