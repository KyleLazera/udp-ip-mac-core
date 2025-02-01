`ifndef ETH_MAC_WR_MON
`define ETH_MAC_WR_MON

class eth_mac_wr_monitor extends uvm_driver;
`uvm_component_utils(eth_mac_wr_monitor)

virtual eth_mac_wr_if wr_if; 
uvm_analysis_port#(eth_mac_wr_if) a_port;
string TAG = "eth_mac_wr_mon";

function void new(string name = "eth_mac_wr_monitor", uvm_component parent);
    super.new(name, parent);
endfunction : new

virtual function void build_phase(uvm_phase phase);
    super.new(phase);
    /* Fetch virtual interface for writing to DUT*/
    if(!uvm_config_db#(virtual eth_mac_wr_if)::get(this, "", "eth_mac_wr_if", wr_if)) 
        `uvm_fatal(TAG, "Failed to fecth eth_mac_wr virtual interface");
endfunction : build_phase

virtual task main_phase(uvm_phase phase);
    super.new(phase);

    forever begin

    end 

endtask : main_phase

endclass : eth_mac_wr_driver

`endif //ETH_MAC_WR_MON