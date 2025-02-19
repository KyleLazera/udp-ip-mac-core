`ifndef ETH_MAC_TX_SEQ
`define ETH_MAC_TX_SEQ

`include "eth_mac_base_seq.sv"

class eth_mac_tx_seq extends eth_mac_base_seq;
    `uvm_object_utils(eth_mac_tx_seq)

    function new(string name = "eth_mac_tx_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        eth_mac_item tx_fifo = eth_mac_item::type_id::create("tx_fifo");

        generate_packet(tx_fifo.tx_data);
        //Send item to tx driver
        start_item(tx_fifo);
        finish_item(tx_fifo);

    endtask : body

endclass : eth_mac_tx_seq

`endif //ETH_MAC_TX_SEQ