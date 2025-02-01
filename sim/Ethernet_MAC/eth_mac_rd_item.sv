`ifndef ETH_MAC_RD_ITEM
`define ETH_MAC_RD_ITEM

class eth_mac_rd_item extends uvm_sequence_item;
    `uvm_object_utils(eth_mac_rd_item)
    
    /* Variables */
    bit fifo_rdy;
    
    function void new(string name = "eth_mac_rd_item");
        super.new(name);
    endfunction : new

endclass : eth_mac_rd_item

`endif //ETH_MAC_WR_ITEM