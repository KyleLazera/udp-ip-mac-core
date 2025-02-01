`ifndef ETH_MAC_WR_DRV
`define ETH_MAC_WR_DRV

class eth_mac_wr_driver extends uvm_driver#(eth_mac_wr_item);
`uvm_component_utils(eth_mac_wr_driver)

virtual eth_mac_wr_if wr_if;
string TAG = "eth_mac_wr_drv";

function void new(string name = "eth_mac_wr_driver", uvm_component parent);
    super.new(name, parent);
endfunction : new

virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    /* Fetch virtual interface for writing to DUT*/
    if(!uvm_config_db#(virtual eth_mac_wr_if)::get(this, "", "eth_mac_wr_if", wr_if))
        `uvm_fatal(TAG, "Failed to fecth eth_mac_wr virtual interface");
endfunction : build_phase

virtual task main_phase(uvm_phase phase);
    eth_mac_wr_item wr_item;
    super.main_phase(phase);    

    forever begin
        //Fetch sequence item to write
        seq_item_port.get_next_item(wr_item);
        //Drive data to the tx_fifo
        wr_if.tx_fifo_drive_data(wr_item.tx_fifo);
        seq_item_port.item_done();
    end 

endtask : main_phase

endclass : eth_mac_wr_driver

`endif //ETH_MAC_WR_DRV