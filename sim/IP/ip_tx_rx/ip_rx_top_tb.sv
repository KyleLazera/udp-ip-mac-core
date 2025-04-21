`include "../common/ip_if.sv"
`include "../common/ip_pkg.sv"

module ip_rx_top_tb;

localparam RX_IP = 1'b0;
localparam TX_IP = 1'b1;

import ip_pkg::*;

// Clock & Reset Signals
bit clk_100;
bit reset_n;

//instantiate IP header & ip_tx class instance
ip_pckt_t tx_ip_pckt, rx_ip_pckt;
ip_agent ip_rx_inst;

//IP Header Interface
ip_if ip_hdr_if(.i_clk(clk_100), .i_resetn(reset_n));

always #5 clk_100 = ~clk_100;

//Initialize Clock and reset values
initial begin 
    clk_100 = 1'b0;
    reset_n = 1'b0;
    #100;
    reset_n = 1'b1;
end

/* DUT Instantantiation */
ipv4_rx #(
    .AXI_STREAM_WIDTH(8)
) ip_rx (
   .i_clk(clk_100),
   .i_reset_n(reset_n),
    .s_eth_hdr_valid(ip_hdr_if.ip_tx_hdr_valid),
    .s_eth_hdr_rdy(ip_hdr_if.ip_tx_hdr_rdy),
    .s_eth_rx_src_mac_addr(ip_hdr_if.eth_tx_src_mac_addr),
    .s_eth_rx_dst_mac_addr(ip_hdr_if.eth_tx_dst_mac_addr),
    .s_eth_rx_type(ip_hdr_if.eth_tx_type),
    .s_rx_axis_tdata(ip_hdr_if.axi_tx.s_axis_tdata),
    .s_rx_axis_tvalid(ip_hdr_if.axi_tx.s_axis_tvalid),
    .s_rx_axis_tlast(ip_hdr_if.axi_tx.s_axis_tlast),
    .s_rx_axis_trdy(ip_hdr_if.axi_tx.s_axis_trdy),
    .m_ip_hdr_trdy(ip_hdr_if.eth_rx_hdr_trdy),
    .m_ip_hdr_tvalid(ip_hdr_if.eth_rx_hdr_tvalid),
    .m_ip_rx_src_ip_addr(ip_hdr_if.ip_rx_src_ip_addr),
    .m_ip_rx_dst_ip_addr(ip_hdr_if.ip_rx_dst_ip_addr),
    .m_eth_rx_src_mac_addr(ip_hdr_if.eth_rx_src_mac_addr),
    .m_eth_rx_dst_mac_addr(ip_hdr_if.eth_rx_dst_mac_addr),
    .m_eth_rx_type(ip_hdr_if.eth_rx_type),    
    .m_rx_axis_tdata(ip_hdr_if.axi_rx.m_axis_tdata),
    .m_rx_axis_tvalid(ip_hdr_if.axi_rx.m_axis_tvalid),
    .m_rx_axis_tlast(ip_hdr_if.axi_rx.m_axis_tlast),
    .m_rx_axis_trdy(ip_hdr_if.axi_rx.m_axis_trdy),
    .bad_packet()        
);
 

initial begin   
    ip_rx_inst = new();
    //Init AXI data lines 
    ip_hdr_if.axi_tx.init_axi_tx();
    ip_hdr_if.axi_rx.init_axi_rx();

    //Wait for reset to be asserted
    @(posedge reset_n);

    fork
        begin
            forever 
                // Check the packets transmitted vs recieved 
                ip_rx_inst.self_check(.tx_pckt(tx_ip_pckt), .rx_pckt(rx_ip_pckt), .tx_ip(1'b0)); 
        end
        begin 
            for(int i = 0; i < 50; i++) begin
                int prob_not_ipv4 = $urandom_range(7, 10);
                int prob_bad_checksum = $urandom_range(11, 15);

                // Using the randomly generated variable, there will be a packet that is not IPv4 or has a bad checksum
                // periodically transmitted to the module
                if(i%prob_not_ipv4 == 0)
                    ip_rx_inst.ip_cfg.version_is_ipv4 = 1'b0;
                else if(i%prob_bad_checksum == 0) 
                    ip_rx_inst.ip_cfg.bad_checksum = 1'b1;
                else begin
                    ip_rx_inst.ip_cfg.bad_checksum = 1'b0;
                    ip_rx_inst.ip_cfg.version_is_ipv4 = 1'b1;
                end
                
                // Generate a full IP Packet & ethernet header and transmit to the IP rx module
                ip_rx_inst.generate_packet(tx_ip_pckt);
                ip_rx_inst.encapsulate_ip_packet(tx_ip_pckt);                
                ip_hdr_if.drive_eth_packet(tx_ip_pckt);
                ->ip_rx_inst.tx_pckt_evt;
                @(ip_rx_inst.scb_complete);
            end
        end
        begin 
            forever begin
                // Sample both the AXI-Stream packet and the header data
                ip_hdr_if.read_raw_packet(rx_ip_pckt);    
                ->ip_rx_inst.rx_pckt_evt;   
            end     
        end
    join_any
    

    #1000;

    $finish;

end

endmodule : ip_rx_top_tb