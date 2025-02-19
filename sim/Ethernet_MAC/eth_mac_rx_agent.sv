`ifndef ETH_MAC_RX_AGENT
`define ETH_MAC_RX_AGENT

`include "eth_mac_rx_driver.sv"
`include "eth_mac_rx_monitor.sv"
`include "eth_mac_rx_seqr.sv"

class eth_mac_rx_agent extends uvm_agent;
    `uvm_component_utils(eth_mac_rx_agent)

    eth_mac_rx_seqr     rx_seqr;
    eth_mac_rx_driver   rx_driver;
    eth_mac_rx_monitor  rx_monitor;

    /* Analysis Export */
    uvm_analysis_port#(eth_mac_item) rx_mon_a_port;
    uvm_analysis_port#(eth_mac_item) rx_drv_a_port;    

    function new(string name = "eth_mac_rx_agent", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase); 
        /* Instantiate components */
        rx_driver = eth_mac_rx_driver::type_id::create("rx_driver", this);
        rx_monitor = eth_mac_rx_monitor::type_id::create("rx_monitor", this);
        rx_seqr = eth_mac_rx_seqr::type_id::create("rx_seqr", this);
    endfunction : build_phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        rx_driver.seq_item_port.connect(rx_seqr.seq_item_export);
        //Connect analysis ports
        rx_drv_a_port = rx_driver.drv_scb_port;
        rx_mon_a_port = rx_monitor.rx_mon_scb_port;
        
    endfunction : connect_phase

endclass : eth_mac_rx_agent

`endif //ETH_MAC_RX_AGENT