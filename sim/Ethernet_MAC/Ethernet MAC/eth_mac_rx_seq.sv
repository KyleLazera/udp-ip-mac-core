`ifndef ETH_MAC_RX_SEQ
`define ETH_MAC_RX_SEQ

`include "eth_mac_base_seq.sv"

class eth_mac_rx_seq extends eth_mac_base_seq;
    `uvm_object_utils(eth_mac_rx_seq)

    function new(string name = "eth_mac_rx_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        eth_mac_item tx_rgmii = eth_mac_item::type_id::create("tx_rgmii");

        generate_packet(tx_rgmii.tx_data);
        //Send item to rx driver
        start_item(tx_rgmii);
        finish_item(tx_rgmii);

    endtask : body

endclass : eth_mac_rx_seq

`endif //ETH_MAC_RX_SEQ