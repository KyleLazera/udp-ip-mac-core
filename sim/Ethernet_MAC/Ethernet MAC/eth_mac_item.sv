`ifndef ETH_MAC_ITEM
`define ETH_MAC_ITEM

class eth_mac_item extends uvm_sequence_item;
    `uvm_object_utils(eth_mac_item)

    bit[7:0] tx_data[$];
    bit[7:0] rx_data[$];

    function new(string name = "eth_mac_item");
        super.new(name);
    endfunction : new

    virtual function void do_copy(uvm_object rhs);
        eth_mac_item rhs_item;

        if(!$cast(rhs_item, rhs)) begin
            `uvm_error("TRANS_ITEM", "RHS is not type of tx_mac_trans_item")
            return;
        end

        //Copy values
        this.tx_data = rhs_item.tx_data;
        this.rx_data = rhs_item.rx_data;

    endfunction : do_copy    
endclass : eth_mac_item

`endif //ETH_MAC_ITEM