`ifndef _RX_MAC_DRIVER
`define _RX_MAC_DRIVER

class rx_mac_driver extends uvm_driver#(rx_mac_rgmii_item);
    /* Utility Macros */
    `uvm_component_utils(rx_mac_driver)
    
    /* Virutal Interface */
    virtual rx_mac_if vif;
    
    /* Constructor */
    function new(string name = "Driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new
    
    /* Build phase function - used to attach virtual interface to the config database */
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Fetch virtual interface from the config database
        if(!uvm_config_db#(virtual rx_mac_if)::get(this, "", "rx_mac_vif", vif))
            `uvm_fatal("DRV", "Could not get vif");
            
    endfunction : build_phase
    
    /* Run phase - Main task that operates during simulation */
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            //Instance of transaction item to hold object recieved from sequencer
            rx_mac_rgmii_item rgmii_item;

            //Fetch the item from the sequencer
            seq_item_port.get_next_item(rgmii_item);
            
            /* Drive Signals to the vif */
            drive_item(rgmii_item);
            
            //Signal to sequencer to transmit next item
            seq_item_port.item_done();
        end
    endtask : run_phase
    
    /* Task that drives the generated signals to the DUT Interface */
    virtual task drive_item(rx_mac_rgmii_item rgmii_item);
        vif.s_rx_axis_trdy <= rgmii_item.fifo_rdy;
        vif.rgmii_mac_rx_data <= rgmii_item.data;
        vif.rgmii_mac_rx_dv <= rgmii_item.dv;
        vif.rgmii_mac_rx_er <= rgmii_item.er;
        @(posedge vif.clk);   
    endtask : drive_item
    
endclass : rx_mac_driver

`endif //_RX_MAC_DRIVER