`ifndef ETH_MAC_TX_SEQR
`define ETH_MAC_TX_SEQR

class eth_mac_tx_seqr extends uvm_sequencer#(eth_mac_item);
    `uvm_component_utils(eth_mac_tx_seqr)

    function new(string name = "eth_mac_tx_seqr", uvm_component parent);
        super.new(name, parent);
    endfunction: new

endclass : eth_mac_tx_seqr

`endif //ETH_MAC_TX_SEQR