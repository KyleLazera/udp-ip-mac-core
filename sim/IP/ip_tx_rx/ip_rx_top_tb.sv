`include "../../common/axi_stream_rx_bfm.sv"
`include "../../common/axi_stream_tx_bfm.sv"
`include "ip_if.sv"
`include "ip_pkg.sv"

module ip_rx_top_tb;

import ip_pkg::*;

localparam FWFT = 1'b1;

// Clock & Reset Signals
bit clk_100;
bit reset_n;

//instantiate IP header & ip_tx class instance
ip_tx_hdr_t ip_hdr;
ip ip_rx_inst;

// AXI Stream Interface Declarations
axi_stream_tx_bfm axi_tx(.s_aclk(clk_100), .s_sresetn(reset_n));
axi_stream_rx_bfm axi_rx(.m_aclk(clk_100), .m_sresetn(reset_n));
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
    .s_eth_hdr_valid(ip_hdr_if.s_eth_hdr_tvalid),
    .s_eth_hdr_rdy(ip_hdr_if.s_eth_hdr_trdy),
    .s_eth_rx_src_mac_addr(ip_hdr_if.m_eth_src_mac_addr),
    .s_eth_rx_dst_mac_addr(ip_hdr_if.m_eth_dst_mac_addr),
    .s_eth_rx_type(ip_hdr_if.m_eth_type),
    .s_rx_axis_tdata(axi_tx.s_axis_tdata),
    .s_rx_axis_tvalid(axi_tx.s_axis_tvalid),
    .s_rx_axis_tlast(axi_tx.s_axis_tlast),
    .s_rx_axis_trdy(axi_tx.s_axis_trdy),
    .m_ip_hdr_trdy(),
    .m_ip_hdr_tvalid(),
    .m_ip_rx_src_ip_addr(),
    .m_ip_rx_dst_ip_addr(),
    .m_eth_rx_src_mac_addr(),
    .m_eth_rx_dst_mac_addr(),
    .m_eth_rx_type(),    
    .m_rx_axis_tdata(axi_rx.m_axis_tdata),
    .m_rx_axis_tvalid(axi_rx.m_axis_tvalid),
    .m_rx_axis_tlast(axi_rx.m_axis_tlast),
    .m_rx_axis_trdy(axi_rx.m_axis_trdy),
    .bad_packet()        
);
 

initial begin
    //Init axi lines
    axi_tx.init_axi_tx();
    axi_rx.init_axi_rx();

    //Wait for reset to be asserted
    @(posedge reset_n);

    repeat(3) begin

        fork
            begin 
                //ip_rx_inst.generate_header_data(ip_hdr);                
                //ip_rx_inst.generate_payload();
                ip_rx_inst.generate_ip_packet(ip_hdr);

                fork
                    begin ip_hdr_if.drive_ethernet_hdr(); end
                    //Bursts randomized and FWFT enabled
                    begin axi_tx.axis_transmit_basic(tx_data, 1'b1, FWFT); end               
                join
                                               
            end
            begin 
                axi_rx.axis_read(rx_data); 
                //ip_rx_inst.check(ip_hdr);
            end
        join

        
    end

    #1000;

    $finish;

end

endmodule : ip_rx_top_tb