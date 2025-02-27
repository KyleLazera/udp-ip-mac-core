`ifndef TC_RD_WR
`define TC_RD_WR

`include "eth_mac_base_test.sv"

class eth_rd_wr_seq extends uvm_sequence;
    `uvm_object_utils(eth_rd_wr_seq)
    //Get handle to virtual sequencer
    `uvm_declare_p_sequencer(eth_mac_virtual_seqr)
    
    uvm_phase   start_phase;
    
    function new(string name = "rd_wr_seq");
        super.new(name);
    endfunction : new
       
    virtual task pre_body();        
        start_phase = this.get_starting_phase();
        
        if(start_phase != null) begin
            start_phase.raise_objection(this);
            `uvm_info("RD_WR_SEQ", "Objection raised", UVM_MEDIUM);
        end
    endtask : pre_body
    
    virtual task body();
        eth_mac_rx_seq     rx_seq;   
        eth_mac_tx_seq     tx_seq;   

        `uvm_info("RD_WR_SEQ", "Starting another iteration", UVM_MEDIUM);

        //Set the link speed by recieving a packet first
        `uvm_do_on(rx_seq, p_sequencer.rx_vseqr);

        //Drive data in full duplex mode 
        fork
            begin
                repeat(10)
                    `uvm_do_on(rx_seq, p_sequencer.rx_vseqr)
            end
            begin
                repeat(10)
                    `uvm_do_on(tx_seq, p_sequencer.tx_vseqr)
            end
        join
        
        `uvm_info("RD_WR_SEQ", "Case Sequence is complete", UVM_MEDIUM);
    endtask : body
    
    virtual task post_body();
        if(start_phase != null) begin 
            `uvm_info("RD_WR_SEQ", "dropping objection", UVM_MEDIUM)
            start_phase.drop_objection(this);
        end
    endtask : post_body
    
endclass : eth_rd_wr_seq

//Test case for sequence above
class tc_full_duplex_random extends eth_mac_base_test;
    `uvm_component_utils(tc_full_duplex_random)

    function new(string name = "tx_rd_wr", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        int link_speed;
        super.build_phase(phase);

        cfg.enable_rx_monitor();
        cfg.enable_tx_monitor();
        link_speed = $urandom_range(0, 2);

        case(link_speed)
            0 : cfg.set_link_speed(cfg.GBIT_SPEED);
            1 : cfg.set_link_speed(cfg.MB_100_SPEED);
            2 : cfg.set_link_speed(cfg.MB_10_SPEED);
        endcase
       
        //Set rd_wr sequence as the default sequence to run 
        uvm_config_db#(uvm_object_wrapper)::set(this, "eth_mac_env.v_seqr.main_phase", "default_sequence", 
                                                eth_rd_wr_seq::type_id::get());                                                              
    endfunction : build_phase
    
    task main_phase(uvm_phase phase);
        super.main_phase(phase);
        uvm_top.print_topology();
    endtask : main_phase    

endclass : tc_full_duplex_random

`endif //TC_RD_WR