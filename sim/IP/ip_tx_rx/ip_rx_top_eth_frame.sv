
`include "../common/ip_if.sv"
`include "ip_eth_frame.sv"

/* Tests the ipv4_rx module with ETH_FRAME parameter set, therefore, the AXI-Stream data contains the IP
 * packet encapsulated within an ethernet header frame.
 */

module ip_rx_top_eth_frame;

import ip_pkg::*;

// Clock & Reset Signals
bit clk_100;
bit reset_n;

//instantiate IP header & ip_tx class instance
ip_pckt_t tx_ip_pckt, rx_ip_pckt;
ip_eth_frame ip_rx_inst;

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
    .AXI_STREAM_WIDTH(8),
    .ETH_FRAME(1)
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
            repeat(50) begin
                ip_rx_inst.set_config();                
                // Generate a full IP Packet & ethernet header and transmit to the IP rx module
                ip_rx_inst.generate_packet(tx_ip_pckt);
                ip_rx_inst.encap_eth_ip_packet(tx_ip_pckt);                
                ip_hdr_if.axi_tx.axis_transmit_basic(.data(tx_ip_pckt.payload), .bursts(1'b0), .fwft(1'b1));
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

endmodule : ip_rx_top_eth_frame