`ifndef _RX_MAC_SCB
`define _RX_MAC_SCB

class rx_mac_scb extends uvm_scoreboard;
    /* Utility macros - Register with factory */
    `uvm_component_utils(rx_mac_scb)
    
    //Connect to the UVM analysis port
    uvm_analysis_imp #(rx_mac_rgmii_item, rx_mac_scb) analysis_port;
    
    /* Constructor */
    function new(string name = "Scoreboard", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    /* Instantiate the analysis port in build phase */
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        //Instantiate analysis port
        analysis_port = new("analysis_imp", this);        
    endfunction : build_phase
    
    /* Add functional verification here */
    virtual function write(rx_mac_rgmii_item item);
        `uvm_info("SCB", "Item Recieved", UVM_HIGH);
    endfunction : write    
    
endclass : rx_mac_scb

`endif //_RX_MAC_SCB