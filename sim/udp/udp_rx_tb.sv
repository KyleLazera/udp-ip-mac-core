`include "udp_pkg.sv"
`include "udp_if.sv"

module udp_rx_tb;

import udp_pkg::*;

// Clock & Reset Signals
bit clk_100;
bit reset_n;

// Instantiate the UDP interface
udp_if udp_hdr_if(.i_clk(clk_100), .i_reset_n(reset_n));
//  UDP pkt struct
udp_pkt_t tx_pckt, rx_pckt;
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
udp_rx#(.AXI_DATA_WIDTH(8))
DUT(
    .i_clk(clk_100),
    .i_reset_n(reset_n),
    .s_axis_tdata(udp_hdr_if.axi_tx.s_axis_tdata),
    .s_axis_tvalid(udp_hdr_if.axi_tx.s_axis_tvalid),
    .s_axis_tlast(udp_hdr_if.axi_tx.s_axis_tlast),
    .s_axis_trdy(udp_hdr_if.axi_tx.s_axis_trdy),
    .m_axis_tdata(udp_hdr_if.axi_rx.m_axis_tdata),
    .m_axis_tvalid(udp_hdr_if.axi_rx.m_axis_tvalid),
    .m_axis_tlast(udp_hdr_if.axi_rx.m_axis_tlast),
    .m_axis_trdy(udp_hdr_if.axi_rx.m_axis_trdy),
    .s_udp_hdr_trdy(udp_hdr_if.tx_udp_hdr_trdy),
    .s_udp_hdr_tvalid(udp_hdr_if.tx_udp_hdr_tvalid),
    .s_udp_src_port(udp_hdr_if.tx_udp_src_port),
    .s_udp_dst_port(udp_hdr_if.tx_udp_dst_port),
    .s_udp_length_port(udp_hdr_if.tx_udp_length),
    .s_udp_hdr_checksum(udp_hdr_if.tx_udp_hdr_checksum)
);

initial begin
    udp_rx_agent = new();
    udp_hdr_if.axi_tx.init_axi_tx();
    udp_hdr_if.axi_rx.init_axi_rx();  

    fork
        // Generate encapsulated packet, and pass via AXI-Stream
        begin
            repeat(100) begin
                udp_rx_agent.gen_udp_pkt(tx_pckt);
                udp_rx_agent.encap_udp_data(tx_pckt);
                udp_hdr_if.drive_udp_payload_axi(tx_pckt);
                @(udp_rx_agent.scb_complete);
            end
        end
        // Read the data from the output of the rx_udp module & compare
        begin
            forever begin
                udp_hdr_if.sample_de_encap_data(rx_pckt);
                udp_rx_agent.de_encap_udp_hdr(tx_pckt);
                udp_rx_agent.self_check(tx_pckt, rx_pckt);
            end
        end
    join_any

    $display("//////////////////////////////////////////////////");
    $display("Test Passed");
    $display("//////////////////////////////////////////////////");

    #1000;

    $finish;
end

endmodule : udp_rx_tb