`ifndef _RX_MAC_TEST
`define _RX_MAC_TEST

`include "rx_mac_env.sv"
`include "rx_mac_seq.sv"

class rx_mac_test extends uvm_test;
    /* Utility macros */
    `uvm_component_utils(rx_mac_test)
    
    /* components */
    rx_mac_env          env;
    rx_mac_seq          seq;
    virtual rx_mac_if   vif;
    
    /* Constructor */
    function new(string name = "rx_mac_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new
    
    /* Build phase - initialize components */
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        //Init the environemnt
        env = rx_mac_env::type_id::create("env", this);
        
        //Get virtual interface and set it in the config db
        if(!uvm_config_db#(virtual rx_mac_if)::get(this, "", "rx_mac_vif", vif))
            `uvm_fatal("TEST", "Failed to get virtual interface.");
            
        uvm_config_db#(virtual rx_mac_if)::set(this, "env.agent.*", "rx_mac_vif", vif);
        
        //Create sequence and randomize
        seq = rx_mac_seq::type_id::create("sequence");
        seq.randomize();
    endfunction : build_phase
    
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        
        //Raise objection to ensure test uses simulation runtime
        phase.raise_objection(this);
        
        //Apply reset before starting simulus generation
        apply_reset();
        
        //Start the sequence on sequencer
        seq.start(env.agent.seq);
        
        //Small Delay
        #200;
        
        //Drop objection so simulation can finish
        phase.drop_objection(this);      
    endtask : run_phase
    
    virtual task apply_reset();
        vif.reset_n = 1'b0;
        repeat(5) @(posedge vif.clk);
        vif.reset_n = 1'b1;
    endtask : apply_reset
    
endclass : rx_mac_test

`endif //_RX_MAC_TEST