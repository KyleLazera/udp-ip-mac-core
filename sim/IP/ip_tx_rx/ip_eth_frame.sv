
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
            tx_pckt.eth_hdr.src_mac_addr,
            tx_pckt.eth_hdr.dst_mac_addr,
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

    /* Self Checking function to compare the encapsulated & De-encapsulated packets */
    task self_check(ref ip_pckt_t tx_pckt, ref ip_pckt_t rx_pckt, input bit tx_ip);

        // Wait for the tx packet to be recieved
        @(tx_pckt_evt);

        // Do not wait for the RX data event if IP Version is not IPv4 or if the bad checksum flag is raised
        if(tx_pckt.ip_hdr.version != 4'd4) begin
            $display("//////////////////////////////////////");
            $display("IP Version != IPv4 - Packet Dropped");
            $display("//////////////////////////////////////");
            ->scb_complete;
            return;
        end 
        else if(ip_cfg.bad_checksum == 1'b1) begin
            $display("//////////////////////////////////////");
            $display("Back Checksum - Packet Dropped");
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
            encap_eth_ip_packet(tx_pckt);
        end 
        // If we are testing the RX IP Module - de-encapsulate the tx data before comparing with the rx_data
        else begin
            de_encap_packet(tx_pckt);
        end
        
        //Ensure the packets are the correct size
        assert(tx_pckt.payload.size() == rx_pckt.payload.size()) $display("Tx Packet Size: %0d == Rx Packet Size: %0d MATCH", tx_pckt.payload.size(), rx_pckt.payload.size());
            else begin
                $display("Tx Packet Size: %0d != Rx Packet Size: %0d MISMATCH", tx_pckt.payload.size(), rx_pckt.payload.size()); 
                $stop;
            end

        // Compare data wihtin packets
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