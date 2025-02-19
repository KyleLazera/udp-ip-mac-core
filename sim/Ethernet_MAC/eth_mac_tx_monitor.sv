`ifndef ETH_MAC_TX_MON
`define ETH_MAC_TX_MON

class eth_mac_tx_monitor extends uvm_monitor;
`uvm_component_utils(eth_mac_tx_monitor)

virtual eth_mac_wr_if wr_if; 
uvm_analysis_port#(eth_mac_item) tx_mon_scb_port;
string TAG = "eth_mac_wr_mon";

function new(string name = "eth_mac_tx_monitor", uvm_component parent);
    super.new(name, parent);
endfunction : new

virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    /* Fetch virtual interface for writing to DUT*/
    if(!uvm_config_db#(virtual eth_mac_wr_if)::get(this, "", "eth_mac_wr_if", wr_if)) 
        `uvm_fatal(TAG, "Failed to fecth eth_mac_wr virtual interface");

    tx_mon_scb_port = new("tx_mon_scb_port", this);
endfunction : build_phase

virtual task main_phase(uvm_phase phase);
    eth_mac_item real_data, copied_data;
    super.main_phase(phase);    

    forever begin
        //todo: Possibly remove the needs for a copied item        
        
        @(wr_if.clk_125);
        
        if(wr_if.reset_n) begin 
            eth_mac_item real_data = eth_mac_item::type_id::create("real_data");
            eth_mac_item copied_data = eth_mac_item::type_id::create("copied_data");
            //Read data from the RGMII end of DUT 
            //todo: Add support for gbit/mbit (DDR and SDR)          
            wr_if.read_rgmii_data(real_data.rx_data);           
           `uvm_info("tx_monitor", $sformatf("tx monitor size: %0d", real_data.rx_data.size()), UVM_MEDIUM)           
            //Copy the sampled data into the copied item
            copied_data.copy(real_data);
            `uvm_info("tx_monitor", $sformatf("tx monitor copied data size: %0d", copied_data.rx_data.size()), UVM_MEDIUM)
            //Send the copied data to the scb
            tx_mon_scb_port.write(copied_data);            
        end
    end 

endtask : main_phase

endclass : eth_mac_tx_monitor

`endif //ETH_MAC_TX_MON