`ifndef ETH_MAC_RX_DRV
`define ETH_MAC_RX_DRV

`include "eth_mac.sv"

class eth_mac_rx_driver extends uvm_driver#(eth_mac_item);
`uvm_component_utils(eth_mac_rx_driver)

uvm_analysis_port#(eth_mac_item) drv_scb_port;
virtual eth_mac_rd_if rd_if;
string TAG = "eth_mac_rx_driver";

function new(string name = "eth_mac_rx_driver", uvm_component parent);
    super.new(name, parent);
endfunction : new

virtual function void build_phase(uvm_phase phase);    
    super.build_phase(phase);
    //Fetch Virtual interface
    if(!uvm_config_db#(virtual eth_mac_rd_if)::get(this, "", "eth_mac_rd_if", rd_if))
        `uvm_fatal(TAG, "Failed to fecth rd virtual interface");   

    drv_scb_port = new("drv_scb_port", this);
endfunction : build_phase

virtual task main_phase(uvm_phase phase);
    eth_mac_item tx_item, tx_item_copy;
    eth_mac eth_mac_base;
    super.main_phase(phase);    

    /* Instantiate instace of eth_mac for simulation */
    eth_mac_base = eth_mac::type_id::create("eth_mac_base");

    forever begin
        tx_item_copy = eth_mac_item::type_id::create("tx_item_copy");
        //Fetch sequence item to write
        seq_item_port.get_next_item(tx_item);
        //Copy data to send to the screoboard for reference
        tx_item_copy.copy(tx_item);

        //Send copied data to the scoreboard
        drv_scb_port.write(tx_item_copy);

        //Encapsulate data before sending on RGMII
        eth_mac_base.encapsulate_data(tx_item.tx_data);        
        
        //Drive data to the DUT (RGMII Side)
        fork
            begin
                //Generate rxc clock for the rgmii data 
                rd_if.generate_clock(); 
            end
            begin
                //Drive the rgmii data based on the rxc 
                rd_if.rgmii_drive_data(tx_item.tx_data);
            end
        join_any

        //todo: Send some junk data for an IFG

        //Signal seqr for more data    
        seq_item_port.item_done();
        
    end 
endtask : main_phase

endclass : eth_mac_rx_driver

`endif //ETH_MAC_RX_DRV