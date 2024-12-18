`ifndef _FIFO_CASE_0
`define _FIFO_CASE_0

`include "fifo_base_test.sv"

/* This module holds case0, which is used to read and write to the FIFO simultaneously */

/* Case0 Sequence that is set as default sequence to run for case0 test */
class case0_sequence extends uvm_sequence;
    `uvm_object_utils(case0_sequence)
    //Get handle to virtual sequencer
    `uvm_declare_p_sequencer(virtual_sequencer)
    
    uvm_phase   start_phase;
    
    function new(string name = "case0_seq");
        super.new(name);
    endfunction : new
       
    virtual task pre_body();        
        start_phase = this.get_starting_phase();
        
        if(start_phase != null) begin
            start_phase.raise_objection(this);
            `uvm_info("CASE0_SEQ", "Objection raised", UVM_MEDIUM);
        end
    endtask : pre_body
    
    virtual task body();
        wr_sequence     wr_seq;
        rd_sequence     rd_seq;   
           
        repeat(10000) begin
            `uvm_do_on(wr_seq, p_sequencer.v_wr_seqr)
            `uvm_do_on(rd_seq, p_sequencer.v_rd_seqr)
        end
        
        `uvm_info("CASE0_SEQ", "Case Sequence is complete", UVM_MEDIUM);
    endtask : body
    
    virtual task post_body();
        if(start_phase != null) begin 
            `uvm_info("my_case0", "dropping objection", UVM_MEDIUM)
            start_phase.drop_objection(this);
        end
    endtask : post_body
    
endclass : case0_sequence

/* Test class for case0 sequence */
class fifo_case0 extends fifo_base_test;
    `uvm_component_utils(fifo_case0)
    
    function new(string name = "case0", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
       
        //Set case0_sequence as the default sequence to run 
        uvm_config_db#(uvm_object_wrapper)::set(this, "fifo_env.v_seqr.main_phase", "default_sequence", 
                                                case0_sequence::type_id::get());                                                              
    endfunction : build_phase
    
    task main_phase(uvm_phase phase);
        super.main_phase(phase);
        uvm_top.print_topology();
    endtask : main_phase
    
endclass : fifo_case0

`endif //_FIFO_CASE_0
