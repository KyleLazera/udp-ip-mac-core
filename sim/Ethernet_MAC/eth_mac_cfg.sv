`ifndef ETH_MAC_CFG
`define ETH_MAC_CFG

class eth_mac_cfg extends uvm_object;
    `uvm_object_utils(eth_mac_cfg)

    /* Config Variables */
    local bit rx_enable = 0;

    function new(string name = "eth_mac_cfg");
        super.new(name);
    endfunction : new

    /* Configuration functions */
    function disable_rx_monitor();
        rx_enable = 0;
    endfunction : disable_rx_monitor

    function enable_rx_monitor();
        rx_enable = 1;
    endfunction : enable_rx_monitor    

    function bit get_rx_enable();
        return rx_enable;
    endfunction : get_rx_enable

endclass : eth_mac_cfg

`endif //ETH_MAC_CFG