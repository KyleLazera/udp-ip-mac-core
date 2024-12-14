`ifndef _FIFO_REFERENCE_MODEL
`define _FIFO_REFERENCE_MODEL

class fifo_reference_model extends uvm_component;
    `uvm_component_utils(fifo_reference_model)
    
    /* Anlaysis port - sends data to the scoreboard */
    uvm_analysis_port#(wr_item) wr_ap;
    /* Blocking port - Recieves data from the wr_agent (blocks until wr_agent has data to send) */
    uvm_blocking_get_port#(wr_item) port;
    
    function new(string name = "fifo_reference", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Initialize the ports
        wr_ap = new("wr_analysis_port", this);
        port = new("wr_blocking_port", this);
    endfunction : build_phase
    
    virtual task run_phase(uvm_phase phase);
        /* Transaction item to hold the recieved data */
        wr_item rec_item, copy_item;
        super.run_phase(phase);
        
        forever begin
            //Get data from wr_agent - block if there is no data available
            port.get(rec_item);
            //To copy item, create a new instance of the transaction item
            copy_item = new("new_transaction");
            copy_item.copy(rec_item);
            //Send the copied item to the scoreboard
            wr_ap.write(copy_item);
        end
        
    endtask : run_phase
    
endclass : fifo_reference_model

`endif //_FIFO_REFERENCE_MODEL