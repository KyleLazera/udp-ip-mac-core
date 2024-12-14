`ifndef _FIFO_CASE_0
`define _FIFO_CASE_0

`include "fifo_base_test.sv"

/* Case0 Sequence that is set as default sequence to run for case0 test */
class case0_sequence extends uvm_sequence;
    `uvm_object_utils(case0_sequence)
    //Get handle to virtual sequencer
    `uvm_declare_p_sequencer(virtual_sequencer)
    
    function new(string name = "case0_seq");
        super.new(name);
    endfunction : new
    
    virtual task pre_body();
        if(starting_phase != null)
            starting_phase.raise_objection(this);
    endtask : pre_body
    
    virtual task body();
        wr_sequence     wr_seq;
        rd_sequence     rd_seq;
        
        repeat(10) begin
            `uvm_do_on(wr_seq, p_sequencer.v_wr_seqr)
            `uvm_info("case0", "Sent 7 done", UVM_MEDIUM)
            `uvm_do_on(rd_seq, p_sequencer.v_rd_seqr)
            `uvm_info("case0", "Get 7 done", UVM_MEDIUM)
        end
    endtask : body
    
    virtual task post_body();
        if(starting_phase != null) begin 
            `uvm_info("my_case0", "starting_pase is drop", UVM_MEDIUM)
            starting_phase.drop_objection(this);
        end
    endtask : post_body
    
endclass : case0_sequence

/* Test class for case0 sequencer */
class fifo_case0 extends fifo_base_test;
    `uvm_component_utils(fifo_case0)
    
    function new(string name = "case0", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Set case0 as the default sequence to run 
        uvm_config_db#(uvm_object_wrapper)::set(this, "env.v_seqr.run_phase", "default_seq", 
                                                case0_sequence::type_id::get());
    endfunction : build_phase
    
    task main_phase(uvm_phase phase);
        super.main_phase(phase);
        uvm_top.print_topology();
    endtask : main_phase
    
endclass : fifo_case0

`endif //_FIFO_CASE_0
