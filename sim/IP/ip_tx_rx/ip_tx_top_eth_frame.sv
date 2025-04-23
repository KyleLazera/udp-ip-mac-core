`include "../common/ip_if.sv"
`include "ip_eth_frame.sv"

module ip_tx_top_eth_frame;

import ip_pkg::*;

localparam FWFT = 1'b1;

// Clock & Reset Signals
bit clk_100;
bit reset_n;

//instantiate IP header & ip_tx class instance
ip_pckt_t tx_ip_pckt, rx_ip_pckt;
ip_eth_frame ip_tx_inst;

// AXI Stream Interface Declarations
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
ipv4_tx #(
    .AXI_STREAM_WIDTH(8),
    .ETH_FRAME(1)
) ip_tx (
   .i_clk(clk_100),
   .i_reset_n(reset_n),
   .s_tx_axis_tdata(ip_hdr_if.axi_tx.s_axis_tdata),                 
   .s_tx_axis_tvalid(ip_hdr_if.axi_tx.s_axis_tvalid),                 
   .s_tx_axis_tlast(ip_hdr_if.axi_tx.s_axis_tlast),                  
   .s_tx_axis_trdy(ip_hdr_if.axi_tx.s_axis_trdy), 
   .s_ip_tx_hdr_type(ip_hdr_if.ip_tx_hdr_type),                  
   .s_ip_tx_hdr_valid(ip_hdr_if.ip_tx_hdr_valid),                  
   .s_ip_tx_hdr_rdy(ip_hdr_if.ip_tx_hdr_rdy),                     
   .s_ip_tx_total_length(ip_hdr_if.ip_tx_total_length),              
   .s_ip_tx_protocol(ip_hdr_if.ip_tx_protocol),                 
   .s_ip_tx_src_ip_addr(ip_hdr_if.ip_tx_src_ip_addr),             
   .s_ip_tx_dst_ip_addr(ip_hdr_if.ip_tx_dst_ip_addr), 
   .s_eth_tx_src_mac_addr(ip_hdr_if.eth_tx_src_mac_addr),
   .s_eth_tx_dst_mac_addr(ip_hdr_if.eth_tx_dst_mac_addr),
   .s_eth_tx_type(ip_hdr_if.eth_tx_type),                                 
   .m_tx_axis_tdata(ip_hdr_if.axi_rx.m_axis_tdata),                 
   .m_tx_axis_tvalid(ip_hdr_if.axi_rx.m_axis_tvalid),                
   .m_tx_axis_tlast(ip_hdr_if.axi_rx.m_axis_tlast),                  
   .m_tx_axis_trdy(ip_hdr_if.axi_rx.m_axis_trdy),
   .m_eth_hdr_trdy(ip_hdr_if.eth_rx_hdr_trdy),
   .m_eth_hdr_tvalid(ip_hdr_if.eth_rx_hdr_tvalid),
   .m_eth_src_mac_addr(ip_hdr_if.eth_rx_src_mac_addr),                                
   .m_eth_dst_mac_addr(ip_hdr_if.eth_rx_dst_mac_addr),                                 
   .m_eth_type(ip_hdr_if.eth_rx_type)     
);

initial begin
    ip_tx_inst = new();
    //Init axi lines
    ip_hdr_if.axi_tx.init_axi_tx();
    ip_hdr_if.axi_rx.init_axi_rx();

    //Wait for reset to be asserted
    @(posedge reset_n);

    fork
        begin
            forever
                ip_tx_inst.self_check(.tx_pckt(tx_ip_pckt), .rx_pckt(rx_ip_pckt), .tx_ip(1'b1)); 
        end
        begin 
            repeat(100) begin
                ip_tx_inst.generate_packet(tx_ip_pckt);                
                ip_hdr_if.drive_ip_payload(tx_ip_pckt);  
                ->ip_tx_inst.tx_pckt_evt; 
                @(ip_tx_inst.scb_complete); 
            end                                         
        end
        begin 
            forever begin
                ip_hdr_if.axi_rx.axis_read(rx_ip_pckt.payload);
                ->ip_tx_inst.rx_pckt_evt;              
            end
        end
    join_any

    #1000;

    $finish;

end

endmodule : ip_tx_top_eth_frame