`ifndef TC_WR_ONLY
`define TC_WR_ONLY

`include "eth_mac_base_test.sv"

//TODO: Move this into its own file - Possibly make a folder that contains all sequences
class eth_wr_only_seq extends uvm_sequence;
    `uvm_object_utils(eth_wr_only_seq)
    //Get handle to virtual sequencer
    `uvm_declare_p_sequencer(eth_mac_virtual_seqr)
    
    uvm_phase   start_phase;
    
    function new(string name = "wr_only_seq");
        super.new(name);
    endfunction : new
       
    virtual task pre_body();        
        start_phase = this.get_starting_phase();
        
        if(start_phase != null) begin
            start_phase.raise_objection(this);
            `uvm_info("WR_ONLY_SEQ", "Objection raised", UVM_MEDIUM);
        end
    endtask : pre_body
    
    virtual task body();
        eth_mac_tx_seq     tx_seq;   
           
        repeat(10) begin
            `uvm_info("TC_SEQ", "Starting another iteration", UVM_MEDIUM);
            `uvm_do_on(tx_seq, p_sequencer.tx_vseqr)
        end
        
        `uvm_info("WR_ONLY_SEQ", "Case Sequence is complete", UVM_MEDIUM);
    endtask : body
    
    virtual task post_body();
        if(start_phase != null) begin 
            `uvm_info("WR_ONLY_SEQ", "dropping objection", UVM_MEDIUM)
            start_phase.drop_objection(this);
        end
    endtask : post_body
    
endclass : eth_wr_only_seq

//Test case for sequence above
class tc_eth_mac_wr_only extends eth_mac_base_test;
    `uvm_component_utils(tc_eth_mac_wr_only)

    function new(string name = "tc_wr_only", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Disable RX for this test case
        cfg.disable_rx_monitor();  
        cfg.enable_tx_monitor(); 
        cfg.set_link_speed(cfg.GBIT_SPEED);     
       
        //Set wr_only as the default sequence to run 
        uvm_config_db#(uvm_object_wrapper)::set(this, "eth_mac_env.v_seqr.main_phase", "default_sequence", 
                                                eth_wr_only_seq::type_id::get());                                                              
    endfunction : build_phase
    
    task main_phase(uvm_phase phase);
        super.main_phase(phase);
        uvm_top.print_topology();
    endtask : main_phase    

endclass : tc_eth_mac_wr_only

`endif //TC_WR_ONLY