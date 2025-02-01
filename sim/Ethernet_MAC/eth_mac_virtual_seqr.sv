`ifndef ETH_MAC_V_SEQR
`define ETH_MAC_V_SEQR

class eth_mac_virtual_seqr extends uvm_sequencer;
    `uvm_component_utils(eth_mac_virtual_seqr)

    /* Sequencers */
    eth_mac_wr_seqr wr_vseqr;

    function void new(string name = "eth_mac_vseqr", uvm_component parent);
        super.new(name, parent);
    endfunction : new

endclass : eth_mac_virtual_seqr

`endif //ETH_MAC_V_SEQR