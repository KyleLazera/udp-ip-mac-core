
`include "ip_pkg.sv"
`include "../../common/axi_stream_rx_bfm.sv"
`include "../../common/axi_stream_tx_bfm.sv"

interface ip_if
(
    input bit i_clk,
    input bit i_resetn    
);

    import ip_pkg::*;

    // Instantiate AXI-Stream Interface
    axi_stream_tx_bfm axi_tx(.s_aclk(i_clk), .s_sresetn(i_resetn));
    axi_stream_rx_bfm axi_rx(.m_aclk(i_clk), .m_sresetn(i_resetn));

    /* Tx IP/Ethernet Header Data */
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

   /* IP TX Methods */

    /* Drives the IP Header & Ethernet header info to the the ip tx module */
    task drive_ip_hdr(ip_hdr_t ip_hdr);
        //Raise the valid flag indicating valid Header data
        ip_tx_hdr_valid <= 1'b1;
        //Drive the generated IP data
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

    /* Read out the Ethernet/IP Headers from the rx IP */
    task read_eth_header(ref ip_pckt_t rx_ip_pckt);
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
        end

        // Lower the ready flag
        eth_rx_hdr_trdy <= 1'b0;
        @(posedge i_clk);

    endtask : read_eth_header    

    /* Drives IP payload with AXI-Stream data and IP/Ethernet header in parallel */
    task drive_ip_payload(ip_pckt_t ip_packet);
        fork
            drive_ip_hdr(ip_packet.ip_hdr);
            axi_tx.axis_transmit_basic(ip_packet.payload);
        join
    endtask : drive_ip_payload

    /* Reads AXI-Stream data and ethernet header data in parallel */
    task read_encap_data(ref ip_pckt_t rx_packet);
        bit [7:0] rx_data [$];

        fork
            axi_rx.axis_read(rx_data);
            read_eth_header(rx_packet);
        join

        // Before copying data over, clear the rx payload
        rx_packet.payload.delete();

        foreach(rx_data[i])
            rx_packet.payload[i] = rx_data[i];

        rx_data.delete();

    endtask : read_encap_data

   /* IP RX Methods */

    /* Task that drives ethernet header data - Used for the RX ip module */
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

    /* Read out the Ethernet/IP Headers from the rx IP */
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

    /* Task used to read the de-encapsulated data from the rx ip module */
    task read_raw_packet(ref ip_pckt_t rx_ip_pckt);
        bit [7:0] rx_data[$];        
        
        fork
            axi_rx.axis_read(rx_data);
            read_pckt_header(rx_ip_pckt);
        join

        rx_ip_pckt.payload.delete();

        foreach(rx_data[i]) begin
            rx_ip_pckt.payload[i] = rx_data[i];
        end

        rx_data.delete();

    endtask : read_raw_packet


endinterface : ip_if