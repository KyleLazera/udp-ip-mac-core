`ifndef ETH_MAC_RD_ITEM
`define ETH_MAC_RD_ITEM

class eth_mac_rd_item extends uvm_sequence_item;
    `uvm_object_utils(eth_mac_rd_item)
    
    localparam DATA_WIDTH = 8;
    
    /* Variables */
    logic rgmii_rxclk;                                   
    rand logic [DATA_WIDTH-1:0] rgmii_data;            
    logic rgmii_rxctl;                                 
    logic [DATA_WIDTH-1:0] rx_fifo_data;          
    logic fr_fifo_valid;                               
    logic rx_fifo_tuser;                                
    logic rx_fifo_tlast;                                
    logic rx_mac_trdy;                                     
    
    function new(string name = "eth_mac_rd_item");
        super.new(name);
    endfunction : new

endclass : eth_mac_rd_item

`endif //ETH_MAC_WR_ITEM