`ifndef ETH_MAC_BASE_SEQ
`define ETH_MAC_BASE_SEQ

/* 
* Original Author : Kyle Lazera 
* Description: This is a base sequence class that the tx_seq and rx_sequence inherit from.
*/

class eth_mac_base_seq extends uvm_sequence#(eth_mac_item);
    `uvm_object_utils(eth_mac_base_seq)

    /* Parameters */
    localparam SMALL_PACKETS = 2'b00;
    localparam LARGE_PACKETS = 2'b01;
    localparam SMALL_AND_LARGE_PACKETS = 2'b10;

    /* Variables */
    bit [1:0] packet_size = 2'b10;

    function new(string name = "eth_mac_base_seq");
        super.new(name);         
    endfunction : new

    function void set_packet_size(bit [1:0] size);
        packet_size = size;
    endfunction : set_packet_size

    function void generate_packet(ref bit[7:0] tx_data[$]);
        bit[7:0] data_byte;
        int pckt_size;

        pckt_size = $urandom_range(10, 1500);

        `uvm_info("generate_packet", $sformatf("Packet of size %0d generated!", pckt_size), UVM_MEDIUM)

        repeat(pckt_size) begin
            data_byte = $urandom_range(0, 255);
            tx_data.push_back(data_byte);
        end
        
    endfunction : generate_packet

endclass : eth_mac_base_seq

`endif  //ETH_MAC_BASE_SEQ