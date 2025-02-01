`ifndef ETH_MAC_WR_ITEM
`define ETH_MAC_WR_ITEM

class eth_mac_wr_item extends uvm_sequence_item;
    `uvm_object_utils(eth_mac_wr_item)
    
    /* FIFO Write Variables */
    logic [7:0] tx_fifo[$];

    /* RGMII Read Variables */
    logic [7:0] rgmii_data_q[$];
    
    function void new(string name = "eth_mac_wr_item");
        super.new(name);
    endfunction : new

    virtual function void do_copy(uvm_object rhs);
        eth_mac_wr_item rhs_item;

        if(!$cast(rhs_item, rhs)) begin
            `uvm_error("TRANS_ITEM", "RHS is not type of tx_mac_trans_item")
            return;
        end

        //Copy values
        this.tx_fifo = rhs_item.tx_fifo;
        this.rgmii_data_q = rhs_item.rgmii_data_q;

    endfunction : do_copy

endclass : eth_mac_wr_item

`endif //ETH_MAC_WR_ITEM