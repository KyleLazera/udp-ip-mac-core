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
    
    /* Constructor */
    function new(string name = "rx_mac_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new
    
    /* Build phase - initialize components */
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        //Init the environemnt
        env = rx_mac_env::type_id::create("env", this);
        
        //Init the sequence
        seq = rx_mac_seq::type_id::create("sequence");      
    endfunction : build_phase
    
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        
        //Raise objection to ensure test uses simulation runtime
        phase.raise_objection(this);
        
        //Wait for reset to occur
        #100;
        
        repeat(10) begin
            seq.randomize();
            seq.start(env.agent.seq);
        end
     
        //Small Delay
        #200;
        
        //Drop objection so simulation can finish
        phase.drop_objection(this);     
    endtask : run_phase
    
endclass : rx_mac_test

`endif //_RX_MAC_TEST