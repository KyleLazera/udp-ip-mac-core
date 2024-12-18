`ifndef _FIFO_SCB
`define _FIFO_SCB

class fifo_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(fifo_scoreboard)
    
    /* Port that recieves data from the reference model - Data sent to the DUT */
    uvm_blocking_get_port#(wr_item) expected_data;
    /* Port that recieves data from the read agent - actual data from DUT */
    uvm_blocking_get_port#(wr_item) actual_data;
    /* FIFO Queue - Holds the values written into the DUT */
    wr_item expected_fifo[$];
    
    function new(string name = "fifo_scb", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Instantiate ports
        expected_data = new("exp_data", this);
        actual_data = new("act_data", this); 
    endfunction : build_phase
    
    virtual task main_phase(uvm_phase phase);
        wr_item act_data, exp_data;
        super.main_phase(phase);
        
        fork
            fifo_write();
            compare_data();
        join
        
    endtask : main_phase
    
    //Task that writes to the reference FIFO
    task fifo_write();
        forever begin
            wr_item exp_data;
            //Fetch expected data from port, block if there is no data
            expected_data.get(exp_data);
            //Push data into reference FIFO
            expected_fifo.push_back(exp_data);
        end
    endtask : fifo_write
    
    //Compares the expected data in expected_fifo to the actual data recieved from DUT
    task compare_data();
        wr_item act_data, exp_data;
        bit result;
        forever begin
            //Fecth output data from read agent
            actual_data.get(act_data);
            //Check if data is in the expected queue
            if(expected_fifo.size() > 0) begin
                exp_data = expected_fifo.pop_front;
                //Compare the actual data, to the data in the expected fifo
                result = act_data.compare(exp_data);
                //Check if result matched - if not print failed result
                if(!result) 
                    `uvm_error("SCB", $sformatf("Mismatch of expected and actual result. Expected: %0h, Actual: %0h", exp_data, act_data));
            end    
        end
    endtask : compare_data
    
endclass : fifo_scoreboard

`endif //_FIFO_SCB
