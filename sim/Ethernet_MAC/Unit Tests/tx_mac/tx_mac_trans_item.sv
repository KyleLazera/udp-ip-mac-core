`ifndef _TX_MAC_ITEM
`define _TX_MAC_ITEM

class tx_mac_trans_item extends uvm_sequence_item;
    `uvm_object_utils(tx_mac_trans_item)
    
    rand logic [7:0] data_byte;
    rand bit rgmii_rdy;
    
    logic [7:0] payload [$];                //This holds teh payload data (simulates a FIFO)
    logic last_byte [$];                    //This is a queue that holds the last byte data  
    logic rgmii_ready [$];                  //indicates the rgmii is ready to recieve data 
    
    constraint rgmii_const {rgmii_rdy dist {0 := 10, 1 := 90};}
    
    function new(string name = "tx_mac_trans_item");
        super.new(name);
    endfunction : new
    
    virtual function void do_copy(uvm_object rhs);
        tx_mac_trans_item rhs_item;
        
        if(!$cast(rhs_item, rhs)) begin
            `uvm_error("TRANS_ITEM", "RHS is not type of tx_mac_trans_item")
            return;
        end
        
        //Copy values
        this.data_byte = rhs_item.data_byte;
        this.rgmii_rdy = rhs_item.rgmii_rdy;
        this.payload = rhs_item.payload;
        this.last_byte = rhs_item.last_byte;
        this.rgmii_ready = rhs_item.rgmii_ready;
            
    endfunction : do_copy
  
endclass : tx_mac_trans_item

`endif //_TX_MAC_ITEM