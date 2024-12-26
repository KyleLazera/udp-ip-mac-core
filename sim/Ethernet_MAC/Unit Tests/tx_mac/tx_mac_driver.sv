`ifndef _TX_MAC_DRIVER
`define _TX_MAC_DRIVER

`include "uvm_macros.svh"  // Import UVM macros
import uvm_pkg::*;         // Import all UVM classes

//`include "tx_mac_gen.sv"
`include "tx_mac_if.sv"
`include "tx_mac_trans_item.sv"
//`include "tx_mac_cfg.sv"

class tx_mac_driver extends uvm_driver#(tx_mac_trans_item);
    `uvm_component_utils(tx_mac_driver)
    
    bit mii_sel;
    virtual tx_mac_if tx_if;
    
    uvm_analysis_port#(tx_mac_trans_item)   a_port;
    
    function new(string name = "tx_mac_driver", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        //Fetch virtual interface
        if(!uvm_config_db#(virtual tx_mac_if)::get(this, "", "tx_if", tx_if))
            `uvm_error("TX_MAC_DRIVER", "Failed to fetch the virtual interface")
            
        //Fetch the mii_sel configuration
        if(!uvm_config_db#(bit)::get(this, "", "mii_sel", mii_sel))
            `uvm_error("TX_MAC_DRIVER", "Failed to fetch mii configuration")  
            
        a_port = new("a_port", this);                   
                        
    endfunction : build_phase
    
    virtual task run_phase(uvm_phase phase);
        tx_mac_trans_item tx_item, copy_item;
        super.run_phase(phase);
        
        //Init the FIFO signals 
        tx_if.init_fifo();
        
        forever begin
            tx_item = new("tx_item");
            copy_item = new("copy_item");
            
            //Wait for reset - if it is asserted
            while(!tx_if.reset_n)
                @(posedge tx_if.clk);
            
            //Fetch sequence item from seqeuncer
            seq_item_port.get_next_item(tx_item);      
            
            //Drive the data to teh tx_mac module
            tx_if.drive_data(tx_item, mii_sel);                        
            
            //Write raw data from sequencer to the reference model
            a_port.write(tx_item);            
            
            //Notify sequencer that it can recieve a new sequence item
            seq_item_port.item_done();
            
        end
    endtask : run_phase
    
endclass : tx_mac_driver

`endif