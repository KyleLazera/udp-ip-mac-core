
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

   /* Methods */

    /* Drives the IP Header & Ethernet header info to the the ip tx module */
    task drive_ip_hdr(ip_tx_hdr_t ip_hdr);
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

    /* Task that drives ethernet header only - Used for the RX ip module */
    task drive_ethernet_hdr();
        // Dive ethernet header info
        ip_tx_hdr_valid <= 1'b1;
        eth_tx_src_mac_addr <= SRC_MAC_ADDR;
        eth_tx_dst_mac_addr <= DST_MAC_ADDR;
        eth_tx_type <= ETH_TYPE;

        @(posedge i_clk);

        //Wait until the master indicates it is ready then lower the valid flag
        while(!ip_tx_hdr_rdy)
            @(posedge i_clk);

        ip_tx_hdr_valid <= 1'b0;           

    endtask : drive_ethernet_hdr

    /* Read the output ethernet header info + the IP addresses */
    task read_ip_eth_data(ref eth_hdr_t eth_hdr, ref ip_tx_hdr_t ip_hdr);
        //Raise the trdy flag
        eth_rx_hdr_trdy <= 1'b1;
        @(posedge i_clk);

        //If the tvalid flag is not raised, wait for it
        while(!eth_rx_hdr_tvalid)
            @(posedge i_clk);

        if(eth_rx_hdr_trdy & eth_rx_hdr_tvalid) begin
            // Store the recieved ethernet info in the packets
            eth_hdr.src_mac_addr = eth_rx_src_mac_addr;
            eth_hdr.dst_mac_addr = eth_rx_dst_mac_addr;
            eth_hdr.eth_type = eth_rx_type;
            //Store the IP Header info
            ip_hdr.src_ip_addr = ip_rx_src_ip_addr;
            ip_hdr.dst_ip_addr = ip_rx_dst_ip_addr;
        end
    endtask : read_ip_eth_data

    /* Read the output ethernet header info  */
    task read_eth_data(ref eth_hdr_t eth_hdr);
        //Raise the trdy flag
        eth_rx_hdr_trdy <= 1'b1;
        @(posedge i_clk);

        //If the tvalid flag is not raised, wait for it
        while(!eth_rx_hdr_tvalid)
            @(posedge i_clk);

        if(eth_rx_hdr_trdy & eth_rx_hdr_tvalid) begin
            // Store the recieved ethernet info in the packets
            eth_hdr.src_mac_addr = eth_rx_src_mac_addr;
            eth_hdr.dst_mac_addr = eth_rx_dst_mac_addr;
            eth_hdr.eth_type = eth_rx_type;
        end     

        eth_rx_hdr_trdy <= 1'b0;
        @(posedge i_clk);   

    endtask : read_eth_data

endinterface : ip_if