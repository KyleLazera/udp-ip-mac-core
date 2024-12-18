`ifndef _WR_DRIVER
`define _WR_DRIVER

class wr_driver extends uvm_driver#(wr_item);
    /* Register with factory */
    `uvm_component_utils(wr_driver)
    
    /* Variables / Interfaces */
    virtual wr_if wr_if;
    string TAG = "WR_DRIVER";
    
    /* Constructor */
    function new(string name = "wr_driver", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    /* Build phase - Used to get teh virtual interface from configuration db */
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Get virtual interface
        if(!uvm_config_db#(virtual wr_if)::get(this, "", "wr_if", wr_if))
            `uvm_fatal(TAG, "Failed to fetch virtual interface");
    endfunction : build_phase
    
    /* Run phase */
    virtual task main_phase(uvm_phase phase);

        forever begin
            //Instantiate instance of transaction item
            wr_item packet;
            
            while(!wr_if.reset_n)
                @(posedge wr_if.clk_wr);            
        
            //Fetch transaction item from sequencer analysis port
            seq_item_port.get_next_item(packet);
            
            //Transmit data to the DUT
            wr_if.push(packet.wr_data, packet.wr_en);
            
            //Indicate driver is ready for more data
            seq_item_port.item_done();
        end
    endtask : main_phase
    
endclass : wr_driver

`endif //_WR_DRIVER
