`ifndef _RD_MONITOR
`define _RD_MONITOR

//`include "async_fifo_pkg.svh"

class rd_monitor extends uvm_monitor;
    `uvm_component_utils(rd_monitor)
    
    //Analysis port
    uvm_analysis_port#(wr_item) a_port;
    
    //Virtual interface to DUT
    virtual rd_if rd_if;
    string TAG = "RD_MONITOR";
    
    function new(string name = "rd_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Fetch virtual interface
        if(!uvm_config_db#(virtual rd_if)::get(this, "", "rd_if", rd_if))
            `uvm_fatal(TAG, "Failed to get virtual interface");  
        //Init analysis port
        a_port = new("a_port", this);  
    endfunction : build_phase
    
    virtual task main_phase(uvm_phase phase);
        //Instantiate write transaction item to hold data
        wr_item data;
        
        forever begin
            @(posedge rd_if.clk_rd);
            //If we are reading data and FIFO is not empty, fetch data and send to scb
            if(rd_if.rd_en && !rd_if.empty) begin
                data = new("data_out");
                rd_if.read_data(data.wr_data);
                a_port.write(data);
            end
        end
        
    endtask : main_phase
    
endclass : rd_monitor

`endif //_RD_MONITOR