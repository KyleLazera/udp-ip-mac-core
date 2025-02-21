`ifndef ETH_MAC_RX_SEQR
`define ETH_MAC_RX_SEQR

class eth_mac_rx_seqr extends uvm_sequencer#(eth_mac_item);
    `uvm_component_utils(eth_mac_rx_seqr)

    function new(string name = "eth_mac_rx_seqr", uvm_component parent);
        super.new(name, parent);
    endfunction: new

endclass : eth_mac_rx_seqr

`endif //ETH_MAC_WR_SEQR