`ifndef WTH_MAC_WR_SEQR
`define ETH_MAC_WR_SEQR

`include "uvm_macros.svh"  // Import UVM macros
import uvm_pkg::*;         // Import all UVM classes

class eth_mac_wr_seqr extends uvm_sequencer#(eth_mac_wr_item);
    `uvm_component_utils(eth_mac_wr_seqr)

    function void new(string name = "eth_mac_wr_seqr", uvm_component parent);
        super.new(name, parent);
    endfunction: new

endclass : eth_mac_wr_seqr

`endif //ETH_MAC_WR_SEQR