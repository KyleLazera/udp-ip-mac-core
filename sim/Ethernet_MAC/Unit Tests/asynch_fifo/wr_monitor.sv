`ifndef _WR_MONITOR
`define _WR_MONITOR

//`include "async_fifo_pkg.svh"
//`include "fifo_if.sv"

class wr_monitor extends uvm_monitor;
    /* Reg with factory */
    `uvm_component_utils(wr_monitor)
    
    /* Analysis Port to connect with scb */
    uvm_analysis_port#(wr_item) a_port;
    
    /* Variables/Interfaces*/
    virtual wr_if wr_if;
    string TAG = "WR_MONITOR";
    
    /* Constructor */
    function new(string name = "wr_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    /* Build Phase */
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Get virtual interface from config db
        if(!uvm_config_db#(virtual wr_if)::get(this, "", "wr_if", wr_if))
            `uvm_fatal(TAG, "Failed to get virtual interface");
        //Init the analysis port
        a_port = new("a_port", this);
    endfunction : build_phase
    
    /* Main Phase */
    virtual task main_phase(uvm_phase phase);
        /* Instance of write transaction item */
        wr_item wr_transaction;
        
        forever begin
            @(posedge wr_if.clk_wr);
            wr_transaction = new("transaction");
            
            //If wr enable is high & the FIFO is not full... sample data being written in 
            //and write to analysis port
            if(wr_if.wr_en && !wr_if.full) begin
                wr_transaction.wr_data = wr_if.data_in;
                a_port.write(wr_transaction);
            end   
        end
        
    endtask : main_phase    
    
endclass : wr_monitor

`endif //_WR_MONITOR
