`ifndef ETH_MAC_CFG
`define ETH_MAC_CFG

class eth_mac_cfg extends uvm_object;
    `uvm_object_utils(eth_mac_cfg)

    localparam GBIT_SPEED = 2'b00;
    localparam MB_100_SPEED = 2'b01;
    localparam MB_10_SPEED = 2'b10;
    
    /* Config Variables */
    local bit rx_enable = 0;
    local bit tx_enable = 0;
    bit [1:0] link_speed = GBIT_SPEED;

    function new(string name = "eth_mac_cfg");
        super.new(name);
    endfunction : new

    /* Configuration functions */
    function void disable_rx_monitor();
        rx_enable = 0;
    endfunction : disable_rx_monitor

    function void disable_tx_monitor();
        tx_enable = 0;
    endfunction : disable_tx_monitor

    function void enable_tx_monitor();
        tx_enable = 1;
    endfunction : enable_tx_monitor    

    function void enable_rx_monitor();
        rx_enable = 1;
    endfunction : enable_rx_monitor    

    function void set_link_speed(bit [1:0] i_link_speed);
        link_speed = i_link_speed;
    endfunction : set_link_speed

    /* Getter functions */
    function bit get_rx_enable();
        return rx_enable;
    endfunction : get_rx_enable

    function bit get_tx_enable();
        return tx_enable;
    endfunction : get_tx_enable    

endclass : eth_mac_cfg

`endif //ETH_MAC_CFG