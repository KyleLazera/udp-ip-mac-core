`ifndef ETH_MAC_TX_MON
`define ETH_MAC_TX_MON

class eth_mac_tx_monitor extends uvm_monitor;
`uvm_component_utils(eth_mac_tx_monitor)

eth_mac_cfg cfg;

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

    //If tx monitor is disabled return immediately
    if(cfg.get_tx_enable() == 0) begin
        `uvm_info("tx_monitor", "tx monitor disabled", UVM_MEDIUM)
        return;
    end else 
        `uvm_info("tx_monitor", "tx_monitor enabled", UVM_MEDIUM)      

    forever begin        
        @(wr_if.clk_100);      
        
        if(wr_if.reset_n) begin 
            eth_mac_item real_data = eth_mac_item::type_id::create("real_data");
            eth_mac_item copied_data = eth_mac_item::type_id::create("copied_data");
            
            //Read data from the RGMII end of DUT         
            wr_if.read_rgmii_data(real_data.rx_data, cfg.link_speed);           
            
            `uvm_info("tx_monitor", $sformatf("tx monitor size: %0d", real_data.rx_data.size()), UVM_MEDIUM)           
            //Copy the sampled data into the copied item
            copied_data.copy(real_data);

            //foreach(copied_data.rx_data[i])
                //`uvm_info("tx_drv", $sformatf("%0h", copied_data.rx_data[i]), UVM_MEDIUM)  

            //Send the copied data to the scb
            tx_mon_scb_port.write(copied_data);            
        end
    end 

endtask : main_phase

endclass : eth_mac_tx_monitor

`endif //ETH_MAC_TX_MON