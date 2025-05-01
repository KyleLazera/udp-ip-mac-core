`include "udp_top_if.sv"
`include "../udp_pkg.sv"

module udp_top_tb;

import udp_pkg::*;

// Clock & Reset Signals
bit clk_100;
bit reset_n;

// Instantiate the UDP interface
udp_top_if  udp_hdr_if(.i_clk(clk_100), .i_reset_n(reset_n));
udp_if      udp_hdr_rx_if(.i_clk(clk_100), .i_reset_n(reset_n));

//  UDP pkt struct
udp_pkt_t tx_tx_pckt, tx_rx_pckt;
udp_pkt_t rx_tx_pckt, rx_rx_pckt;
udp_top_agent udp_tx_agent;
udp_agent udp_rx_agent;

always #5 clk_100 = ~clk_100;

//Initialize Clock and reset values
initial begin 
    clk_100 = 1'b0;
    reset_n = 1'b0;
    #100;
    reset_n = 1'b1;
end

// DUT
udp#(.AXI_DATA_WIDTH(8), .UDP_CHECKSUM(1), .MAX_PAYLOAD(1472)) 
DUT(
    .i_clk(clk_100),
    .i_reset_n(reset_n),
    .s_udp_tx_hdr_trdy(udp_hdr_if.tx_udp_hdr_trdy),
    .s_udp_tx_hdr_tvalid(udp_hdr_if.tx_udp_hdr_tvalid),
    .s_udp_tx_src_port(udp_hdr_if.tx_udp_src_port),
    .s_udp_tx_dst_port(udp_hdr_if.tx_udp_dst_port),
    .s_ip_tx_src_ip_addr(udp_hdr_if.tx_ip_src_addr),                               
    .s_ip_tx_dst_ip_addr(udp_hdr_if.tx_ip_dst_addr), 
    .s_ip_tx_protocol(udp_hdr_if.tx_ip_protocol),  
    .s_tx_axis_tdata(udp_hdr_if.axi_tx.s_axis_tdata),
    .s_tx_axis_tvalid(udp_hdr_if.axi_tx.s_axis_tvalid),
    .s_tx_axis_tlast(udp_hdr_if.axi_tx.s_axis_tlast),
    .s_tx_axis_trdy(udp_hdr_if.axi_tx.s_axis_trdy),
    .m_udp_tx_hdr_valid(udp_hdr_if.m_tx_hdr_valid),
    .m_udp_tx_length(udp_hdr_if.m_tx_udp_length),
    .m_udp_tx_checksum(udp_hdr_if.m_tx_udp_checksum),
    .m_tx_axis_tdata(udp_hdr_if.axi_rx.m_axis_tdata),
    .m_tx_axis_tvalid(udp_hdr_if.axi_rx.m_axis_tvalid),
    .m_tx_axis_tlast(udp_hdr_if.axi_rx.m_axis_tlast),
    .m_tx_axis_trdy(udp_hdr_if.axi_rx.m_axis_trdy),

    .s_rx_axis_tdata(udp_hdr_rx_if.axi_tx.s_axis_tdata),
    .s_rx_axis_tvalid(udp_hdr_rx_if.axi_tx.s_axis_tvalid),
    .s_rx_axis_tlast(udp_hdr_rx_if.axi_tx.s_axis_tlast),
    .s_rx_axis_trdy(udp_hdr_rx_if.axi_tx.s_axis_trdy),
    .m_rx_axis_tdata(udp_hdr_rx_if.axi_rx.m_axis_tdata),
    .m_rx_axis_tvalid(udp_hdr_rx_if.axi_rx.m_axis_tvalid),
    .m_rx_axis_tlast(udp_hdr_rx_if.axi_rx.m_axis_tlast),
    .m_rx_axis_trdy(udp_hdr_rx_if.axi_rx.m_axis_trdy),
    .s_udp_rx_hdr_trdy(udp_hdr_rx_if.tx_udp_hdr_trdy),
    .s_udp_rx_hdr_tvalid(udp_hdr_rx_if.tx_udp_hdr_tvalid),
    .s_udp_rx_src_port(udp_hdr_rx_if.tx_udp_src_port),
    .s_udp_rx_dst_port(udp_hdr_rx_if.tx_udp_dst_port),
    .s_udp_rx_length_port(udp_hdr_rx_if.tx_udp_length),
    .s_udp_rx_hdr_checksum(udp_hdr_rx_if.tx_udp_hdr_checksum)
);

initial begin
    udp_tx_agent = new();
    udp_rx_agent = new();
    udp_hdr_if.axi_tx.init_axi_tx();
    udp_hdr_if.axi_rx.init_axi_rx(); 

    fork
        /****** TX Data Path ********/
        // TX Data driven to UDP module 
        begin
            repeat(100) begin
                udp_tx_agent.gen_udp_pkt(tx_tx_pckt);
                udp_hdr_if.drive_tx_data(tx_tx_pckt, udp_tx_agent.src_ip_addr, udp_tx_agent.dst_ip_addr);
                @(udp_tx_agent.scb_complete);
            end
        end
        // Read TX Data Output
        begin
            forever begin
                udp_hdr_if.sample_udp_packet(tx_rx_pckt);
                //First de-encapsulate the recieved udp packet
                udp_tx_agent.de_encap_udp_hdr(tx_rx_pckt);
                udp_tx_agent.self_check(tx_tx_pckt, tx_rx_pckt);
            end
        end
        /****** RX Data Path ********/
        //Drive data through RX path
        begin
            repeat(100) begin
                udp_rx_agent.gen_udp_pkt(rx_tx_pckt);
                udp_rx_agent.encap_udp_data(rx_tx_pckt);
                udp_hdr_rx_if.drive_udp_payload_axi(rx_tx_pckt);
                @(udp_rx_agent.scb_complete);
            end
        end
        // Read data from the RX Path
        begin
            forever begin
                udp_hdr_rx_if.sample_de_encap_data(rx_rx_pckt);
                udp_rx_agent.de_encap_udp_hdr(rx_tx_pckt);
                udp_rx_agent.self_check(rx_tx_pckt, rx_rx_pckt);
            end
        end
    join_any

    $display("//////////////////////////////////////////////////");
    $display("Test Passed");
    $display("//////////////////////////////////////////////////");

    #1000;  

    $finish;
end

endmodule : udp_top_tb