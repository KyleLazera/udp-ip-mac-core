`include "../../common/axi_stream_rx_bfm.sv"
`include "../../common/axi_stream_tx_bfm.sv"
`include "ip_if.sv"
`include "ip_tx_pkg.sv"

module ip_tx_top;

import ip_tx_pkg::*;

localparam FWFT = 1'b1;

// Clock & Reset Signals
bit clk_100;
bit reset_n;

//instantiate IP header & ip_tx class instance
ip_tx_hdr_t ip_hdr;
ip_tx ip_tx_inst;

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
ipv4_tx #(
    .AXI_STREAM_WIDTH(8)
) ip_tx (
   .i_clk(clk_100),
   .i_reset_n(reset_n),
   .s_tx_axis_tdata(axi_tx.s_axis_tdata),                 
   .s_tx_axis_tvalid(axi_tx.s_axis_tvalid),                 
   .s_tx_axis_tlast(axi_tx.s_axis_tlast),                  
   .s_tx_axis_trdy(axi_tx.s_axis_trdy), 
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
   .m_tx_axis_tdata(axi_rx.m_axis_tdata),                 
   .m_tx_axis_tvalid(axi_rx.m_axis_tvalid),                
   .m_tx_axis_tlast(axi_rx.m_axis_tlast),                  
   .m_tx_axis_trdy(axi_rx.m_axis_trdy),
   .m_eth_hdr_trdy(),
   .m_eth_hdr_tvalid(),
   .m_eth_src_mac_addr(),                                
   .m_eth_dst_mac_addr(),                                 
   .m_eth_type()     
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
                ip_tx_inst.generate_header_data(ip_hdr);                
                ip_tx_inst.generate_payload();

                fork
                    begin ip_hdr_if.drive_hdr(ip_hdr); end
                    //Bursts randomized and FWFT enabled
                    begin axi_tx.axis_transmit_basic(tx_data, 1'b1, FWFT); end               
                join
                                               
            end
            begin 
                axi_rx.axis_read(rx_data); 
                ip_tx_inst.check(ip_hdr);
            end
        join

        
    end

    #1000;

    $finish;

end

endmodule : ip_tx_top