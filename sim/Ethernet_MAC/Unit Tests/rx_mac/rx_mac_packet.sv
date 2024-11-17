`ifndef _RX_MAC_PCKT
`define _RX_MAC_PCKT

`include "rx_mac_gen.sv"
`include "uvm_macros.svh"  // Import UVM macros
import uvm_pkg::*;         // Import all UVM classes

class rx_eth_packet extends uvm_object;
    /* Utility Macros */
    `uvm_object_utils(rx_eth_packet)
    
    /* Local Parameters */
    localparam HEADER_BYTES = 8;
    localparam CRC_BYTES = 4;
    localparam ETH_HDR = 8'h55;
    localparam ETH_SFD = 8'hD5; 
    
    /* Variables */
    rx_mac_rgmii_item packet [];
    rand int unsigned packet_size;
    
    /* Constraints */
    constraint packet_size_constraint {packet_size inside {[49:1500]};};
    
    /* Constructor */
    function new(string name = "Ethernet_Packet");
        super.new(name);
        this.randomize();
    endfunction : new
    
    /* Function to generate a packet */
    function void generate_packet();
       
       //Init CRC32 class for CRC calculation
       crc32_checksum crc = new();
       
        rx_mac_rgmii_item packet_item;
        logic [31:0] crc_out;
        logic [7:0] data_payload [] = new[packet_size];
        packet = new[packet_size + HEADER_BYTES + CRC_BYTES];
        
        // Generate & add header 
        for(int i = 0; i < HEADER_BYTES; i++) begin
            packet[i] = rx_mac_rgmii_item::type_id::create($sformatf("Header %0d", i));
            
            //8th byte should be the SFD
            if(i < 7)                 
                packet[i].randomize() with {packet_item.data == ETH_HDR;};
            else
                packet[i].randomize() with {packet_item.data == ETH_SFD;};      
        end
        
        //Generate & Append payload
        for(int i = 0; i < packet_size; i++) begin
            packet[HEADER_BYTES + i] = rx_mac_rgmii_item::type_id::create($sformatf("Payload %0d", i));
            packet[HEADER_BYTES + i].randomize();
            data_payload[i] = packet[HEADER_BYTES + i].data;
        end
        
        //Calculate the CRC 
        crc_out = crc.crc32_reference_model(data_payload);
        
        //Append CRC bytes to end of packet
        for(int i = 0; i < CRC_BYTES; i++) begin
            packet[HEADER_BYTES + packet_size + i] = rx_mac_rgmii_item::type_id::create($sformatf("CRC %0d", i));
            packet[HEADER_BYTES + packet_size + i].randomize() with {packet[HEADER_BYTES + packet_size + i].data == crc_out[(i*8) +: 8];};
        end
        
    endfunction : generate_packet
    
endclass : rx_eth_packet

`endif //_RX_MAC_PCKT