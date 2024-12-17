`ifndef _FIFO_BASE_TEST
`define _FIFO_BASE_TEST

class fifo_base_test extends uvm_test;
    `uvm_component_utils(fifo_base_test)
    
    fifo_env        env;
    
    function new(string name = "fifo_base_test", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Init instance of the environment 
        env = fifo_env::type_id::create("fifo_env", this);   
    endfunction : build_phase
    
    virtual function void report_phase(uvm_phase phase);
        //Instance of uvm report server
        uvm_report_server   server;
        //Variable to track number of errors
        int err_num;
        super.report_phase(phase);
        
        server = get_report_server();
        err_num = server.get_severity_count(UVM_ERROR);
        
        if (err_num != 0) 
           $display("TEST CASE FAILED");
        else 
           $display("TEST CASE PASSED");
        
    endfunction : report_phase
    
endclass : fifo_base_test

`endif //_FIFO_BASE_TEST
