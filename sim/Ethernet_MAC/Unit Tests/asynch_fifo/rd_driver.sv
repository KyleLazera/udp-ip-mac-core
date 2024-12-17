`ifndef _RD_DRIVER
`define _RD_DRIVER

class rd_driver extends uvm_driver#(rd_item);
    `uvm_component_utils(rd_driver)
    
    virtual rd_if rd_if;
    string TAG = "RD_DRIVER";
    
    function new(string name = "rd_driver", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Fetch the virtual interface handle
        if(!uvm_config_db#(virtual rd_if)::get(this, "", "rd_if", rd_if))
            `uvm_fatal(TAG, "Failed to fetch virtual interface");
    endfunction : build_phase
    
    virtual task main_phase(uvm_phase phase);
           
        forever begin
            //Init instance of transaction item
            rd_item read;
            
            //Block while we are reseting
            while(!rd_if.reset_n)
                @(posedge rd_if.clk_rd);            
            
            //Get the data from the analysis port and pass to DUT
            seq_item_port.get_next_item(read);
            
            `uvm_info("RD_DRV", $sformatf("Read Enable %0d", read.read_en), UVM_MEDIUM);
            
            //Drive data to DUT         
            rd_if.pop(read.read_en);
            
            //Indicate to sequencer it can send more data
            seq_item_port.item_done();
        end 
    endtask : main_phase
    
endclass : rd_driver

`endif //_RD_DRIVER
