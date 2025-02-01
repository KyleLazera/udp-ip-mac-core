`ifndef ETH_MAC_WR_SEQ
`define ETH_MAC_WR_SEQ

`include "eth_mac_wr_item.sv"

class eth_mac_wr_seq extends uvm_sequence#(eth_mac_wr_item);
    `uvm_object_utils(eth_mac_wr_seq)

    logic [7:0] tx_fifo[$];
    rand logic [7:0] tx_byte;    

    function void new(string name = "eth_mac_wr_seq", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual task body();
        int packet_size;
        eth_mac_wr_item tx_item;

        packet_size = $urandom_range(10, 1500);
        tx_item = eth_mac_wr_item::type_id::create("tx_item");

        /* Populate the tx_fifo with random data */
        for(int i = 0; i < packet_size; i++) begin
            tx_byte.randomize();
            tx_item.tx_fifo.push_back(tx_byte);            
        end

        start_item(tx_item);
        finish_item(tx_item);

    endtask : body

endclass : eth_mac_wr_seq

`endif //ETH_MAC_WR_SEQ