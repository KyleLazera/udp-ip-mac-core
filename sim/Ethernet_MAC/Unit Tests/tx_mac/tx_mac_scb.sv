`ifndef _TX_MAC_SCB
`define _TX_MAC_SCB

`include "tx_mac_trans_item.sv"

class tx_mac_scb extends uvm_scoreboard;
    `uvm_component_utils(tx_mac_scb)
    
    /* Port that recieves data from the reference model */
    uvm_blocking_get_port#(tx_mac_trans_item) expected_data;
    /* Port that recieves data from the monitor - actual data from DUT */
    uvm_blocking_get_port#(tx_mac_trans_item) actual_data;
    
    bit result;
    
    function new(string name = "tx_mac_scb", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Init analysis ports
        expected_data = new("expected_data", this);
        actual_data = new("actual_data", this);
    endfunction : build_phase
    
    virtual task run_phase(uvm_phase phase);
        tx_mac_trans_item   actual_item, exp_item;
        super.run_phase(phase);
        
        forever begin
            //Get the actual output data
            actual_data.get(actual_item);
            
            //get data from the reference model
            expected_data.get(exp_item);
            
            //result = actual_item.compare(exp_item);
            result = (actual_item.payload == exp_item.payload);                
            
            if(!result)
                `uvm_error("TX_MAC_SCB", "Mismatch of the packets")
            
        end
    endtask : run_phase
    
endclass : tx_mac_scb

`endif