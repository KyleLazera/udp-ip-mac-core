`ifndef ETH_MAC_ENV
`define ETH_MAC_ENV

`include "uvm_macros.svh"  // Import UVM macros
import uvm_pkg::*;         // Import all UVM classes

`include "eth_mac_item.sv"
`include "eth_mac_scb.sv"
`include "eth_mac_virtual_seqr.sv"
`include "eth_mac_tx_agent.sv"
`include "eth_mac_rx_agent.sv"
`include "eth_mac.sv"
`include "eth_mac_cfg.sv"

class eth_mac_env extends uvm_env;
    `uvm_component_utils(eth_mac_env)

    /* Configuration varibales */
    bit rx_enable = 0;

    /* Declare Agents & Components */
    eth_mac_tx_agent        tx_agent;
    eth_mac_rx_agent        rx_agent;
    eth_mac_scb             eth_scb;
    eth_mac_virtual_seqr    v_seqr;  
    eth_mac_cfg             cfg;  

    /* Declare FIFO ports */
    uvm_tlm_analysis_fifo#(eth_mac_item) tx_mon_scb;
    uvm_tlm_analysis_fifo#(eth_mac_item) tx_drv_scb;
    uvm_tlm_analysis_fifo#(eth_mac_item) rx_mon_scb;
    uvm_tlm_analysis_fifo#(eth_mac_item) rx_drv_scb;    

    function new(string name = "eth_mac_env", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);   
        
        //Fetch the ethernet configuration
        if (!uvm_config_db#(eth_mac_cfg)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("environment", "Could not get eth_mac_cfg from config_db")
        end    

        /* Instantiate Agents*/
        tx_agent = eth_mac_tx_agent::type_id::create("tx_agent", this);
        rx_agent = eth_mac_rx_agent::type_id::create("rx_agent", this);
        eth_scb = eth_mac_scb::type_id::create("eth_scb", this);
        v_seqr = eth_mac_virtual_seqr::type_id::create("v_seqr", this);     
        
        /* Instantiate FIFO's */
        tx_drv_scb = new("tx_drv_scb");
        tx_mon_scb = new("tx_mon_scb");
        rx_mon_scb = new("rx_mon_scb");
        rx_drv_scb = new("rx_drv_scb");
    endfunction : build_phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        //Pass the config class to components
        rx_agent.rx_monitor.cfg = cfg;
        eth_scb.cfg = cfg;          

        //Connecting teh tx agent anlsysis exports 
        tx_agent.tx_drv_a_port.connect(tx_drv_scb.analysis_export);
        eth_scb.tx_drv_port.connect(tx_drv_scb.blocking_get_export);

        tx_agent.tx_mon_a_port.connect(tx_mon_scb.analysis_export);
        eth_scb.tx_mon_port.connect(tx_mon_scb.blocking_get_export);

        //Connecting the rx agent analysis ports
        rx_agent.rx_drv_a_port.connect(rx_mon_scb.analysis_export);
        eth_scb.rx_drv_port.connect(rx_mon_scb.blocking_get_export);

        rx_agent.rx_mon_a_port.connect(rx_drv_scb.analysis_export);
        eth_scb.rx_mon_port.connect(rx_drv_scb.blocking_get_export);

        //Connect virtual sequencers
        v_seqr.tx_vseqr = tx_agent.tx_seqr;
        v_seqr.rx_vseqr = rx_agent.rx_seqr;

    endfunction : connect_phase

endclass : eth_mac_env

`endif //ETH_MAC_ENV