`ifndef _TX_MAC_MONITOR
`define _TX_MAC_MONITOR

`include "tx_mac_trans_item.sv"

class tx_mac_monitor extends uvm_monitor;
    `uvm_component_utils(tx_mac_monitor)
    
    virtual tx_mac_if tx_if;
    
    uvm_analysis_port#(tx_mac_trans_item) a_port;
    
    function new(string name = "tx_mac_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        //Fecth virtual interface from configuration database
        if(!uvm_config_db#(virtual tx_mac_if)::get(this, "", "tx_if", tx_if))
            `uvm_error("TX_MONITOR", "Failed to fetch virtual interface")
        
        //Init the analysis port
        a_port = new("a_port", this);
    endfunction : build_phase
    
    virtual task run_phase(uvm_phase phase);
        tx_mac_trans_item   tx_item;
        super.run_phase(phase);
        
        tx_item = new("tx_item");
        
        forever begin
            @(posedge tx_if.clk);            
            
            tx_if.monitor_output_data(tx_item);    
            
            //Only write the data once there is no more valid data 
            if(!tx_if.rgmii_mac_tx_dv && (tx_item.payload.size() > 0)) begin
                a_port.write(tx_item);                        
                tx_item.payload.delete();
            end
        end
    endtask : run_phase
    
endclass : tx_mac_monitor

`endif