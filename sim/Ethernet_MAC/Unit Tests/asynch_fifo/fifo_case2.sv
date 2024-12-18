`ifndef FIFO_CASE2
`define FIFO_CASE2

`include "fifo_base_test.sv"

class case2_sequence extends uvm_sequence;
    `uvm_object_utils(case2_sequence)
    `uvm_declare_p_sequencer(virtual_sequencer)
    
    uvm_phase start_phase;
    
    function new(string name = "case1_seq");
        super.new(name);
    endfunction : new
    
    virtual task pre_body();
        start_phase = this.get_starting_phase();
        
        if(start_phase != null)
            start_phase.raise_objection(this);
            
    endtask : pre_body

    virtual task body();
        wr_sequence     wr_seq;
        rd_sequence     rd_seq;
        
        //Write Until FIFO is full
        repeat(500) begin
            `uvm_do_on(wr_seq, p_sequencer.v_wr_seqr)
        end
        
        //Read until FIFO is empty
        repeat(500) 
            `uvm_do_on(rd_seq, p_sequencer.v_rd_seqr)
            
    endtask : body

    virtual task post_body();
        start_phase = this.get_starting_phase();
        
        if(start_phase != null)
            start_phase.drop_objection(this);
            
    endtask : post_body    
    
endclass : case2_sequence

class fifo_case2 extends fifo_base_test;
    `uvm_component_utils(fifo_case2)
    
    function new(string name = "case2", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        //Set case1_sequence as the default sequence to run 
        uvm_config_db#(uvm_object_wrapper)::set(this, "fifo_env.v_seqr.main_phase", "default_sequence", 
                                                case2_sequence::type_id::get());           
    endfunction : build_phase
    
    task main_phase(uvm_phase phase);
        super.main_phase(phase);
        uvm_top.print_topology();        
    endtask : main_phase
    
endclass : fifo_case2

`endif //FIFO_CASE2
