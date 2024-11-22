`ifndef _RX_MAC_MONITOR
`define _RX_MAC_MONITOR

class rx_mac_monitor extends uvm_monitor;
    /* Utility Macros to register with factory */
    `uvm_component_utils(rx_mac_monitor)
    
    /* Virtual Interface */
    virtual rx_mac_if vif;
    
    /* Analysis Port Initialization */
    uvm_analysis_port#(rx_mac_rgmii_item) mon_analysis_port;
    
    /* Constructor */
    function new(string name = "monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new
    
    /* Build Phase - Get the virtual interface from config database */
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Fetch virtual interface from configuration database
        if(!uvm_config_db#(virtual rx_mac_if)::get(this, "", "rx_mac_vif", vif))
            `uvm_fatal("MON", "Could not get vif");
        
        //Instantiate instance of monitor analysis port
        mon_analysis_port = new("mon_analysis_port", this);
    endfunction : build_phase
    
    /* Main task that runs during dimulation */
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            //Wait for the clock to go high
            @(vif.clk);
            //Ensure the reset signal is high (reset not asserted)
            if(vif.reset_n) begin
                //Create transaction item instance 
                rx_mac_rgmii_item fifo_item = rx_mac_rgmii_item::type_id::create("item");
                //Read data values from the AXI Stream signals 
                fifo_item.fifo_data = vif.m_rx_axis_tdata;
                fifo_item.fifo_valid = vif.m_rx_axis_tvalid;
                fifo_item.fifo_error = vif.m_rx_axis_tuser;
                fifo_item.fifo_last = vif.m_rx_axis_tlast;
                //Write the item to the monitor analysis port
                mon_analysis_port.write(fifo_item);
            end
        end        
    endtask : run_phase
    
endclass : rx_mac_monitor

`endif //_RX_MAC_MONITOR