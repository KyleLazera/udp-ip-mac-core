`ifndef ETH_MAC_V_SEQR
`define ETH_MAC_V_SEQR

`include "eth_mac_tx_seqr.sv"

class eth_mac_virtual_seqr extends uvm_sequencer;
    `uvm_component_utils(eth_mac_virtual_seqr)

    /* Sequencers */
    eth_mac_tx_seqr tx_vseqr;
    eth_mac_rx_seqr  rx_vseqr;

    function new(string name = "eth_mac_vseqr", uvm_component parent);
        super.new(name, parent);
    endfunction : new

endclass : eth_mac_virtual_seqr

`endif //ETH_MAC_V_SEQR