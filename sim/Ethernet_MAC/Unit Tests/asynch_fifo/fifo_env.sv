`ifndef _FIFO_ENV
`define _FIFO_ENV

class fifo_env extends uvm_env;
    `uvm_component_utils(fifo_env)
    
    /* Instances of components within the environment */
    wr_agent                wr_fifo;
    rd_agent                rd_fifo;
    fifo_reference_model    model;
    fifo_scoreboard         scb;
    virtual_sequencer       v_seqr;
    
    /* TLM FIFO Ports to connect agents with scb/reference model */
    uvm_tlm_analysis_fifo#(wr_item) agent_model_fifo;
    uvm_tlm_analysis_fifo#(wr_item) model_scb_fifo;
    uvm_tlm_analysis_fifo#(wr_item) agent_scb_fifo;
    
    function new(string name = "fifo_env", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Instantiate each component
        wr_fifo = wr_agent::type_id::create("wr_fifo", this);
        rd_fifo = rd_agent::type_id::create("rd_fifo", this);
        model = fifo_reference_model::type_id::create("model", this);
        scb = fifo_scoreboard::type_id::create("scb", this);
        v_seqr = virtual_sequencer::type_id::create("v_seqr", this);
        //Instantiate TLM FIFO's
        agent_model_fifo = new("agent_model_fifo", this);
        model_scb_fifo = new("model_scb_fifo", this);
        agent_scb_fifo = new("agent_scb_fifo", this);
    endfunction : build_phase
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        `uvm_info("FIFO_ENV", "Connect_phase initiated", UVM_MEDIUM);
        
        /* Connect wr_agent with reference model */
        wr_fifo.a_port.connect(agent_model_fifo.analysis_export);
        model.port.connect(agent_model_fifo.blocking_get_export);
        
        /* Connect ref model with scb */
        model.wr_ap.connect(model_scb_fifo.analysis_export);
        scb.expected_data.connect(model_scb_fifo.blocking_get_export);
        
        /* Connect rd_agent with the scoreboard */
        rd_fifo.a_port.connect(agent_scb_fifo.analysis_export);
        scb.actual_data.connect(agent_scb_fifo.blocking_get_export);
        
        /* Assign the sequencers in virtual sequencer */
        v_seqr.v_wr_seqr = wr_fifo.seqr;
        v_seqr.v_rd_seqr = rd_fifo.seqr;
        
    endfunction : connect_phase
    
endclass : fifo_env

`endif //_FIFO_ENV
