`ifndef _TX_MAC_AGENT
`define _TX_MAC_AGENT

class tx_mac_agent extends uvm_agent;
    `uvm_component_utils(tx_mac_agent)
    
    //Component declarations
    tx_mac_driver                       drv;
    tx_mac_monitor                      mon;
    uvm_sequencer#(tx_mac_trans_item)   seqr;
    
    uvm_analysis_port#(tx_mac_trans_item)   a_port_drv;
    uvm_analysis_port#(tx_mac_trans_item)   a_port_mon;
    
    function new(string name = "tx_mac_agent", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Init components
        drv = tx_mac_driver::type_id::create("tx_mac_driver", this);
        mon = tx_mac_monitor::type_id::create("tx_mac_monitor", this);
        seqr = uvm_sequencer#(tx_mac_trans_item)::type_id::create("tx_mac_seqr", this);
    endfunction : build_phase   
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        //Connect driver and sequencer
        drv.seq_item_port.connect(seqr.seq_item_export);        
        //Connect the driver analysis port agent
        a_port_drv = drv.a_port;
        a_port_mon = mon.a_port;
    endfunction : connect_phase
    
endclass : tx_mac_agent

`endif //_TX_MAC_AGENT
