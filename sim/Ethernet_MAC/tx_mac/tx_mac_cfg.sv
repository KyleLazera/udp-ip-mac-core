`ifndef _TX_MAC_CFG
`define _TX_MAC_CFG

class tx_mac_cfg;
    /* Variables to randomize for each test */
    rand int num_pckt;
    rand bit mii_sel;
    
    /* Constructor */
    function new();
        this.randomize();
    endfunction : new
    
    /* Constraints */
    constraint mii_sel_const{
        mii_sel dist {0 := 50, 1 := 50};
    }
    
    constraint pckt_size_const{
        num_pckt > 5;
        num_pckt <= 50;
    }

endclass : tx_mac_cfg

`endif