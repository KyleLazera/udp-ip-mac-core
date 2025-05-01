`include "../udp_pkg.sv"
`include "../../common/axi_stream_rx_bfm.sv"
`include "../../common/axi_stream_tx_bfm.sv"

interface udp_top_if(
    input bit i_clk,
    input bit i_reset_n
);

    import udp_pkg::*;

    // Instantiate AXI-Stream Interface
    axi_stream_tx_bfm axi_tx(.s_aclk(i_clk), .s_sresetn(i_resetn));
    axi_stream_rx_bfm axi_rx(.m_aclk(i_clk), .m_sresetn(i_resetn));

    // Signal Declarations
    logic tx_udp_hdr_trdy;
    logic tx_udp_hdr_tvalid;
    logic [15:0] tx_udp_src_port;
    logic [15:0] tx_udp_dst_port;
    logic [31:0] tx_ip_src_addr;
    logic [31:0] tx_ip_dst_addr;
    logic [7:0] tx_ip_protocol;


    logic m_tx_hdr_valid;
    logic [15:0] m_tx_udp_length;
    logic [15:0] m_tx_udp_checksum;

    // Drive UDP Header data
    task drive_udp_hdr(udp_pkt_t tx_pckt, logic [31:0] src_ip_addr, logic [31:0] dst_ip_addr);
        
        tx_udp_hdr_tvalid <= 1'b1;

        // Drive the UDP Header data
        tx_udp_src_port <= tx_pckt.src_port;
        tx_udp_dst_port <= tx_pckt.dst_port;
        tx_ip_src_addr <= src_ip_addr;
        tx_ip_dst_addr <= dst_ip_addr;
        tx_ip_protocol <= 8'h11;


        // Wait until the udp module is ready to accept the header data
        do begin
            @(posedge i_clk);
        end while(!tx_udp_hdr_trdy);

        tx_udp_hdr_tvalid <= 1'b0;

    endtask : drive_udp_hdr

    // Drive the AXI-Stream payload data in parallel with the UDP Header Data
    task drive_tx_data(udp_pkt_t tx_pckt, logic [31:0] src_ip_addr, logic [31:0] dst_ip_addr);
        fork
            begin 
                drive_udp_hdr(tx_pckt, src_ip_addr, dst_ip_addr); 
            end
            begin 
                axi_tx.axis_transmit_basic(tx_pckt.udp_payload, 1'b1, 1'b1); 
            end
        join
    endtask: drive_tx_data

    // Sample the Packaged UDP payload
    task sample_udp_packet(ref udp_pkt_t rx_pckt);
        bit [7:0] rx_data[$];

        fork
            begin
                // Read the output data
                axi_rx.axis_read(rx_data);

                // Copy the data into the payload
                rx_pckt.udp_payload.delete();
                foreach(rx_data[i])
                    rx_pckt.udp_payload[i] = rx_data[i];

                rx_data.delete();
            end
            begin
                forever begin
                // Wait until the header valid flag goes high
                while(!m_tx_hdr_valid)
                    @(posedge i_clk);

                if(m_tx_hdr_valid) begin
                    rx_pckt.udp_length = m_tx_udp_length;
                    rx_pckt.udp_checksum = m_tx_udp_checksum;
                end
                @(posedge i_clk);
                end
            end
        join_any

    endtask: sample_udp_packet

    // Drives a full UDP packet via AXI-Stream
    task drive_udp_payload_axi(udp_pkt_t tx_pckt);
        axi_tx.axis_transmit_basic(tx_pckt.udp_payload, 1'b0, 1'b1); 
    endtask : drive_udp_payload_axi



endinterface