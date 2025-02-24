`ifndef ETH_MAC_BASE_SEQ
`define ETH_MAC_BASE_SEQ

/* 
* Original Author : Kyle Lazera 
* Description: This is a base sequence class that the tx_seq and rx_sequence inherit from.
*/

class eth_mac_base_seq extends uvm_sequence#(eth_mac_item);
    `uvm_object_utils(eth_mac_base_seq)

    function new(string name = "eth_mac_base_seq");
        super.new(name);
    endfunction : new

    function void generate_packet(ref bit[7:0] tx_data[$]);
        bit[7:0] data_byte;
        int packet_size;

        //Generate a packet of a random size
        packet_size = $urandom_range(60, 80); //TODO: Change size to be more realistic

        `uvm_info("generate_packet", $sformatf("Packet of size %0d generated!", packet_size), UVM_MEDIUM)

        repeat(packet_size) begin
            data_byte = $urandom_range(0, 255);
            tx_data.push_back(data_byte);
        end
        
    endfunction : generate_packet

endclass : eth_mac_base_seq

`endif  //ETH_MAC_BASE_SEQ