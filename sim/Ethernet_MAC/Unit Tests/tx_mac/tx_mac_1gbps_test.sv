`ifndef _TX_MAC_1GBPS_TEST
`define _TX_MAC_1GBPS_TEST

class tx_mac_1gbps_test extends tx_mac_test;
    `uvm_component_utils(tx_mac_1gbps_test)
    
    tx_mac_seq          seq;    
    
    function new(string name = "tx_mac_1gbps_test", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        //Set the mii select variable to 1 - this indicates 1gbps operation
        uvm_config_db#(bit)::set(this, "tx_mac_env.tx_mac_agent.tx_mac_driver", "mii_sel", 1'b0);
        
        //Create sequence
        seq = tx_mac_seq::type_id::create("tx_mac_seq");               
    endfunction : build_phase
    
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        
        phase.raise_objection(this);
        
        repeat (50) begin
            seq.randomize();
            seq.start(env.tx_agent.seqr);            
        end
        
        #1000;
        phase.drop_objection(this);
    endtask : run_phase    
    
endclass : tx_mac_1gbps_test

`endif //_TX_MAC_1GBPS_TEST
