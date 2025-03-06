`ifndef ETH_MAC_TX_DRV
`define ETH_MAC_TX_DRV

`include "eth_mac.sv"

class eth_mac_tx_driver extends uvm_driver#(eth_mac_item);
`uvm_component_utils(eth_mac_tx_driver)

eth_mac_cfg cfg;

virtual eth_mac_wr_if wr_if;
uvm_analysis_port#(eth_mac_item) tx_drv_scb_port;
string TAG = "eth_mac_wr_drv";

function new(string name = "eth_mac_tx_driver", uvm_component parent);
    super.new(name, parent);
endfunction : new

virtual function void build_phase(uvm_phase phase);    
    super.build_phase(phase);
    /* Fetch virtual interface for writing to DUT*/
    if(!uvm_config_db#(virtual eth_mac_wr_if)::get(this, "", "eth_mac_wr_if", wr_if))
        `uvm_fatal(TAG, "Failed to fecth eth_mac_wr virtual interface");    

    tx_drv_scb_port = new("tx_drv_scb_port", this);
endfunction : build_phase

virtual task main_phase(uvm_phase phase);
    eth_mac_item tx_item, tx_item_copy;
    eth_mac eth_mac_base;
    int num_packets_sent = 1;
    super.main_phase(phase);  
    
    /* Instantiate instace of eth_mac for simulation/reference */
    eth_mac_base = eth_mac::type_id::create("eth_mac_base");      

    @(wr_if.clk_100);

    forever begin
        tx_item_copy = eth_mac_item::type_id::create("tx_item_copy");
        //Fetch sequence item to write
        seq_item_port.get_next_item(tx_item);
        //Copy data to encapsulate and send to the scoreboard for reference
        tx_item_copy.copy(tx_item);

        //Drive original data to the DUT
        wr_if.tx_fifo_drive_data(tx_item.tx_data, (num_packets_sent == cfg.tx_burst_size));        

        //Pass copied data through eth_mac to encapsulate
        eth_mac_base.encapsulate_data(tx_item_copy.tx_data);     
        
        //Send encapsulated data to scb as reference
        tx_drv_scb_port.write(tx_item_copy);
        `uvm_info("tx_driver", $sformatf("size of encapsulated ref data: %0d", tx_item_copy.tx_data.size()), UVM_MEDIUM)
        
        //Signal seqr for more data    
        seq_item_port.item_done();
        
        if(num_packets_sent != cfg.tx_burst_size)
            num_packets_sent++;
    end 
endtask : main_phase

endclass : eth_mac_tx_driver

`endif //ETH_MAC_TX_DRV