
/* This class inherits from the ip_agent & overrides some functions/tasks so they
 * can specifically test the scenario where ETH_FRAME parameter is set
 */

`include "../common/ip_pkg.sv"

import ip_pkg::*;

class ip_eth_frame extends ip_agent;

    /* Encapsulate a packet into an ethernet frame */
    function encap_eth_ip_packet(ref ip_pckt_t tx_pckt);
        logic [111:0] eth_hdr;
        
        // Encapsulate the IP packet
        encapsulate_ip_packet(tx_pckt);
        
        //Encapslate the IP within the ethernet packet
        eth_hdr = {
            tx_pckt.eth_hdr.dst_mac_addr,
            tx_pckt.eth_hdr.src_mac_addr,
            tx_pckt.eth_hdr.eth_type
        };

        for(int i = 0; i < 14; i++) 
            tx_pckt.payload.push_front(eth_hdr[((i+1)*8)-1 -: 8]);
        
    endfunction : encap_eth_ip_packet

    /* Remove the ethernet and IP headers */
    function de_encap_packet(ref ip_pckt_t tx_pckt);
        for(int i = 0; i < 34; i++)
            tx_pckt.payload.pop_front();
    endfunction : de_encap_packet

    /* Self-Checking Functions */
    function void check_ethernet_hdr(ref ip_pckt_t tx_pckt, ref ip_pckt_t rx_pckt);

        // Compare the Source MAC address
        assert(tx_pckt.eth_hdr.src_mac_addr == rx_pckt.eth_hdr.src_mac_addr)
        else begin
            $display("Tx Src MAC: %0h != Rx Src MAC: %0h MISMATCH", tx_pckt.eth_hdr.src_mac_addr, rx_pckt.eth_hdr.src_mac_addr); 
            $stop;
        end

        // Compare the Destination MAC address
        assert(tx_pckt.eth_hdr.dst_mac_addr == rx_pckt.eth_hdr.dst_mac_addr)
        else begin
            $display("Tx Dst MAC: %0h != Rx Dst MAC: %0h MISMATCH", tx_pckt.eth_hdr.dst_mac_addr, rx_pckt.eth_hdr.dst_mac_addr); 
            $stop;
        end

        // Compare the Ethernet Type
        assert(tx_pckt.eth_hdr.eth_type == rx_pckt.eth_hdr.eth_type)
        else begin
            $display("Tx Eth Type: %0h != Rx Eth Type: %0h MISMATCH", tx_pckt.eth_hdr.eth_type, rx_pckt.eth_hdr.eth_type); 
            $stop;
        end

    endfunction : check_ethernet_hdr

    function void check_ip_hdr(ref ip_pckt_t tx_pckt, ref ip_pckt_t rx_pckt, input bit tx_ip);

        if(tx_ip) begin

        assert(tx_pckt.ip_hdr.version == rx_pckt.ip_hdr.version) 
            else begin
                $display("IP tx Version %0h != IP rx Version %0h MISMATCH", tx_pckt.ip_hdr.version, rx_pckt.ip_hdr.version);
                $finish;
            end

        assert(tx_pckt.ip_hdr.length == rx_pckt.ip_hdr.length) 
            else begin
                $display("IP tx Length %0h != IP rx Length %0h MISMATCH", tx_pckt.ip_hdr.length, rx_pckt.ip_hdr.length);
            $finish;
            end

        assert(tx_pckt.ip_hdr.tos == rx_pckt.ip_hdr.tos) 
            else begin
                $display("IP tx TOS %0h != IP rx TOS %0h MISMATCH", tx_pckt.ip_hdr.tos, rx_pckt.ip_hdr.tos);
                $finish;
            end

        assert(tx_pckt.ip_hdr.total_length == rx_pckt.ip_hdr.total_length) 
            else begin
                $display("IP tx Total Length %0h != IP rx Total Length %0h MISMATCH", tx_pckt.ip_hdr.total_length, rx_pckt.ip_hdr.total_length);
                $finish;
            end

        assert(tx_pckt.ip_hdr.ip_hdr_id == rx_pckt.ip_hdr.ip_hdr_id) 
            else begin
                $display("IP tx Header ID %0h != IP rx Header ID %0h MISMATCH", tx_pckt.ip_hdr.ip_hdr_id, rx_pckt.ip_hdr.ip_hdr_id);
                $finish;
            end

        assert(tx_pckt.ip_hdr.ip_hdr_flags == rx_pckt.ip_hdr.ip_hdr_flags) 
            else begin
                $display("IP tx IP Header Flag %0h != IP rx IP Header Flag %0h MISMATCH", tx_pckt.ip_hdr.ip_hdr_flags, rx_pckt.ip_hdr.ip_hdr_flags);
                $finish;
            end

        assert(tx_pckt.ip_hdr.ip_hdr_frag_offset == rx_pckt.ip_hdr.ip_hdr_frag_offset) 
            else begin
                $display("IP tx Fragment offset %0h != IP rx Fragment offset %0h MISMATCH", tx_pckt.ip_hdr.ip_hdr_frag_offset, rx_pckt.ip_hdr.ip_hdr_frag_offset);
                $finish;
            end

        assert(tx_pckt.ip_hdr.ip_hdr_ttl == rx_pckt.ip_hdr.ip_hdr_ttl) 
            else begin 
                $display("IP tx TTL %0h != IP rx TTL %0h MISMATCH", tx_pckt.ip_hdr.ip_hdr_ttl, rx_pckt.ip_hdr.ip_hdr_ttl);
                $finish;
            end

        assert(tx_pckt.ip_hdr.protocol == rx_pckt.ip_hdr.protocol) 
            else begin
                $display("IP tx protocol %0h != IP rx protocol %0h MISMATCH", tx_pckt.ip_hdr.protocol, rx_pckt.ip_hdr.protocol);
                $finish;
            end  

        end

        assert(tx_pckt.ip_hdr.src_ip_addr == rx_pckt.ip_hdr.src_ip_addr) 
            else begin 
                $display("TX IP SRC Addr %0h != RX IP SRC Addr %0h MISMATCH", tx_pckt.ip_hdr.src_ip_addr, rx_pckt.ip_hdr.src_ip_addr);
                $finish;
            end
            
        assert(tx_pckt.ip_hdr.dst_ip_addr == rx_pckt.ip_hdr.dst_ip_addr) 
            else begin
                $display("TX IP DST Addr %0h != RX IP DST Addr %0h MISMATCH", tx_pckt.ip_hdr.dst_ip_addr, rx_pckt.ip_hdr.dst_ip_addr);
                $finish;
            end  

    endfunction : check_ip_hdr

    /* Self Checking function to compare the encapsulated & De-encapsulated packets */
    task self_check(ref ip_pckt_t tx_pckt, ref ip_pckt_t rx_pckt, input bit tx_ip);

        // Wait for the tx packet to be recieved
        @(tx_pckt_evt);

        if(tx_pckt.ip_hdr.version != 4'd4) begin
            $display("//////////////////////////////////////");
            $display("IP Version != IPv4 - Packet Dropped");
            $display("//////////////////////////////////////");
            ->scb_complete;
            return;
        end 
        else if(ip_cfg.bad_checksum == 1'b1) begin
            $display("//////////////////////////////////////");
            $display("Bad Checksum - Packet Dropped");
            $display("//////////////////////////////////////");
            ->scb_complete;
            return;   
        end  
        else if(ip_cfg.bad_total_length == 1'b1) begin
            $display("//////////////////////////////////////");
            $display("Bad Length - Packet Dropped");
            $display("//////////////////////////////////////");
            ->scb_complete;
            return;   
        end

        // Wait for the RX packet to be recieved
        @(rx_pckt_evt); 

        if(tx_ip) begin
            de_encapsulate_eth_packet(rx_pckt);
            de_encapsulate_ip_packet(rx_pckt);
        end else
            de_encap_packet(tx_pckt);

        // Compare the Ethernet Headers of teh tx and rx packet
        check_ethernet_hdr(tx_pckt, rx_pckt);

        // Compare the IP Headers of the tx and rx packets
        check_ip_hdr(tx_pckt, rx_pckt, tx_ip);

        // Compare payload wihtin packets
        foreach(rx_pckt.payload[i]) begin
            assert(rx_pckt.payload[i] == tx_pckt.payload[i]) 
                else begin 
                    $display("rx_data [%0d] %0h != tx_data [%0d] %0h MISMATCH", i, rx_pckt.payload[i], i, tx_pckt.payload[i]); 
                    $stop; 
                end
        end 

        rx_pckt.payload.delete();
        ->scb_complete;  

    endtask : self_check

endclass : ip_eth_frame