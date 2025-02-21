`ifndef ETH_MAC_RX_MON
`define ETH_MAC_RX_MON

`include "eth_mac_cfg.sv"

class eth_mac_rx_monitor extends uvm_monitor;
    `uvm_component_utils(eth_mac_rx_monitor)

    virtual eth_mac_rd_if rd_if;
    eth_mac_cfg cfg;
    uvm_analysis_port#(eth_mac_item) rx_mon_scb_port;

    function new(string name = "eth_mac_rx_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //fetch virtual interface to monitor data from DUT
        if(!uvm_config_db#(virtual eth_mac_rd_if)::get(this, "", "eth_mac_rd_if", rd_if))
            `uvm_fatal("rx_monitor", "Failed to fecth rd virtual interface")         

        rx_mon_scb_port = new("rx_mon_scb", this);
    endfunction : build_phase

    virtual task main_phase(uvm_phase phase);
        eth_mac_item rx_item;
        super.main_phase(phase);
        
        @(rd_if.clk_100);
        
        //If rx monitor is disabled return immediately
        if(cfg.get_rx_enable() == 0) begin
            `uvm_info("rx_monitor", "rx monitor disabled", UVM_MEDIUM)
            return;
        end else 
            `uvm_info("rx_monitor", "rx_monitor enabled", UVM_MEDIUM)

        forever begin
            rx_item = eth_mac_item::type_id::create("rx_item", this);

            //Sample the recieved FIFO Data
            rd_if.read_rx_fifo(rx_item.rx_data);

            //Send teh rx data to teh scb for comparison
            rx_mon_scb_port.write(rx_item);
        end
    endtask : main_phase

endclass : eth_mac_rx_monitor

`endif //ETH_MAC_RX_MON