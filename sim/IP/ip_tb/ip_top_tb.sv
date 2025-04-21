`include "../common/ip_if.sv"
`include "../common/ip_pkg.sv"

module ip_top_tb;

import ip_pkg::*;

// Clock & Reset Signals
bit clk_100;
bit reset_n;

//instantiate IP header & ip_tx class instance
ip_pckt_t tx_ip_tx_pckt, tx_ip_rx_pckt;
ip_pckt_t rx_ip_tx_pckt, rx_ip_rx_pckt;
ip_agent ip_rx_inst, ip_tx_inst;

//IP Header Interface
ip_if tx_ip_if(.i_clk(clk_100), .i_resetn(reset_n));
ip_if rx_ip_if(.i_clk(clk_100), .i_resetn(reset_n));

//Generate Clock
always #5 clk_100 = ~clk_100;

//Initialize Signals
initial begin 
    clk_100 = 1'b0;
    reset_n = 1'b0;
    #100;
    reset_n = 1'b1;
end

// DUT Instantiation
ip#(.AXI_STREAM_WIDTH(8)) ip_dut(
    .i_clk(clk_100),
    .i_reset_n(reset_n),

    /******************************************* TX To Ethernet MAC *************************************/

    /* IP Payload Input - Used for Tx*/
    .s_ip_tx_hdr_valid(tx_ip_if.ip_tx_hdr_valid),                                       
    .s_ip_tx_hdr_rdy(tx_ip_if.ip_tx_hdr_rdy),                                         
    .s_ip_tx_hdr_type(tx_ip_if.ip_tx_hdr_type),                                   
    .s_ip_tx_total_length(tx_ip_if.ip_tx_total_length),                              
    .s_ip_tx_protocol(tx_ip_if.ip_tx_protocol),                                   
    .s_ip_tx_src_ip_addr(tx_ip_if.ip_tx_src_ip_addr),                               
    .s_ip_tx_dst_ip_addr(tx_ip_if.ip_tx_dst_ip_addr),                               
    .s_eth_tx_src_mac_addr(tx_ip_if.eth_tx_src_mac_addr),                            
    .s_eth_tx_dst_mac_addr(tx_ip_if.eth_tx_dst_mac_addr),                                
    .s_eth_tx_type(tx_ip_if.eth_tx_type),                                    

    /* AXI Stream Payload Inputs */
    .s_tx_axis_tdata(tx_ip_if.axi_tx.s_axis_tdata),                   
    .s_tx_axis_tvalid(tx_ip_if.axi_tx.s_axis_tvalid),                                         
    .s_tx_axis_tlast(tx_ip_if.axi_tx.s_axis_tlast),                                          
    .s_tx_axis_trdy(tx_ip_if.axi_tx.s_axis_trdy),                                         

    /* Tx Ethernet Frame Output */
    .m_tx_axis_tdata(tx_ip_if.axi_rx.m_axis_tdata),                  
    .m_tx_axis_tvalid(tx_ip_if.axi_rx.m_axis_tvalid),                                        
    .m_tx_axis_tlast(tx_ip_if.axi_rx.m_axis_tlast),                                         
    .m_tx_axis_trdy(tx_ip_if.axi_rx.m_axis_trdy),                                           

    /******************************************* RX From Ethernet MAC *************************************/

    /* Ethernet Frame Input - Input to eth_rx */
    .s_rx_axis_tdata(rx_ip_if.axi_tx.s_axis_tdata),
    .s_rx_axis_tvalid(rx_ip_if.axi_tx.s_axis_tvalid),
    .s_rx_axis_tlast(rx_ip_if.axi_tx.s_axis_tlast),
    .s_rx_axis_trdy(rx_ip_if.axi_tx.s_axis_trdy),

    /* De-encapsulated Frame Output */
    .m_ip_hdr_trdy(rx_ip_if.eth_rx_hdr_trdy),
    .m_ip_hdr_tvalid(rx_ip_if.eth_rx_hdr_tvalid),
    .m_ip_rx_src_ip_addr(rx_ip_if.ip_rx_src_ip_addr),
    .m_ip_rx_dst_ip_addr(rx_ip_if.ip_rx_dst_ip_addr),
    .m_eth_rx_src_mac_addr(rx_ip_if.eth_rx_src_mac_addr),
    .m_eth_rx_dst_mac_addr(rx_ip_if.eth_rx_dst_mac_addr),
    .m_eth_rx_type(rx_ip_if.eth_rx_type),    

    /* IP Frame Payload */
    .m_rx_axis_tdata(rx_ip_if.axi_rx.m_axis_tdata),
    .m_rx_axis_tvalid(rx_ip_if.axi_rx.m_axis_tvalid),
    .m_rx_axis_tlast(rx_ip_if.axi_rx.m_axis_tlast),
    .m_rx_axis_trdy(rx_ip_if.axi_rx.m_axis_trdy),

    /* Status Flags */
    .bad_packet()       
);

initial begin
    ip_rx_inst = new();
    ip_tx_inst = new();
    //Init AXI data lines for both tx/rx ip datapaths
    tx_ip_if.axi_tx.init_axi_tx();
    tx_ip_if.axi_rx.init_axi_rx();
    rx_ip_if.axi_tx.init_axi_tx();
    tx_ip_if.axi_rx.init_axi_rx();

    //Wait for reset to be asserted
    @(posedge reset_n);

    //fork
        /* TX Data Path */
        //begin
            fork
                begin
                    forever 
                        ip_tx_inst.self_check(.tx_pckt(tx_ip_tx_pckt), .rx_pckt(tx_ip_rx_pckt), .tx_ip(1'b1));
                end
                // Drive Payload + IP/Ethernet Header 
                begin
                    repeat(3) begin
                        ip_tx_inst.generate_packet(tx_ip_tx_pckt);
                        tx_ip_if.drive_ip_payload(tx_ip_tx_pckt);
                        ->ip_tx_inst.tx_pckt_evt; 
                        @(ip_tx_inst.scb_complete); 
                    end
                end
                // Read Fully packaged IP Payload
                begin
                    forever begin
                        tx_ip_if.axi_rx.axis_read(tx_ip_rx_pckt.payload);
                        ->ip_tx_inst.rx_pckt_evt;  
                    end
                end
            join_any
        //end
        /* RX Data Path */
        /*begin
            fork
                // Drive Recieved Ethernet Packet from eth mac
                begin
                    repeat(3) begin
                        ip_rx_inst.generate_packet(rx_ip_tx_pckt);
                        ip_rx_inst.encapsulate_ip_packet(rx_ip_tx_pckt);
                        rx_ip_if.axi_tx.axis_transmit_basic(.data(rx_ip_tx_pckt.payload), .bursts(1'b1), .fwft(1'b1));
                    end
                end
                // Read de-encapsulated IP packet
                begin
                    forever 
                        rx_ip_if.read_raw_packet(rx_ip_rx_pckt);
                end
            join_any
        end*/
    //join_any

    #1000;
    $finish;

end

endmodule