`ifndef _TX_MAC_MONITOR
`define _TX_MAC_MONITOR

`include "tx_mac_trans_item.sv"

class tx_mac_monitor extends uvm_monitor;
    `uvm_component_utils(tx_mac_monitor)
    
    virtual tx_mac_if tx_if;
    
    typedef enum {IDLE,             //Initial waiting state
                  PREAMBLE,         //Check the preamble
                  PAYLOAD,          //Check the payload
                  CRC,              //Check teh CRC/FCS
                  IFG               //IFG before next packet
                  }state_type;    
    
    uvm_analysis_port#(tx_mac_trans_item) a_port;
    
    function new(string name = "tx_mac_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        //Fecth virtual interface from configuration database
        if(!uvm_config_db#(virtual tx_mac_if)::get(this, "", "tx_if", tx_if))
            `uvm_error("TX_MONITOR", "Failed to fetch virtual interface")
        
        //Init the analysis port
        a_port = new("a_port", this);
    endfunction : build_phase
    
    virtual task run_phase(uvm_phase phase);
        tx_mac_trans_item   tx_item, copy_item;
        int byte_ctr = 0;
        bit last_byte = 1'b0;          
        state_type state = IDLE; 
        super.run_phase(phase);
                             
        tx_item = new("tx_item");
        
        forever begin
        @(posedge tx_if.clk); 
            case(state)
                IDLE : begin
                    //Clear all current variables
                    byte_ctr = 0;
                    //If there is valid data in the FIFO go to the preamble state
                    if(tx_if.s_tx_axis_tvalid)
                        state = PREAMBLE;
                end
                PREAMBLE : begin
                    #1 if(byte_ctr < 7 && tx_if.rgmii_mac_tx_dv) begin
                        //`uvm_info("MON", $sformatf("Preamble Data: %0h", tx_if.rgmii_mac_tx_data), UVM_MEDIUM)  
                        #1 tx_item.payload.push_back(tx_if.rgmii_mac_tx_data);                                                                            
                        byte_ctr++;
                    end else if(byte_ctr >= 7 && tx_if.rgmii_mac_tx_dv) begin
                        #1 tx_item.payload.push_back(tx_if.rgmii_mac_tx_data);   
                        //`uvm_info("MON", $sformatf("Preamble Data: %0h", tx_if.rgmii_mac_tx_data), UVM_MEDIUM)                                                                    
                        byte_ctr = 0;
                        state = PAYLOAD;
                    end 
                                                                                       
                end
                PAYLOAD : begin  
                    //only if data is valid, sample the data
                    #1 if(tx_if.rgmii_mac_tx_dv) begin 
                        tx_item.payload.push_back(tx_if.rgmii_mac_tx_data);   
                        //`uvm_info("MON", $sformatf("Payload Data: %0h", tx_if.rgmii_mac_tx_data), UVM_MEDIUM)                            
                        byte_ctr++;
                    end
                    
                    if(last_byte && byte_ctr > 59) begin
                        last_byte = 1'b0;               
                        state = CRC;
                        byte_ctr = 0;
                    end else begin                                                
                        #1 if(tx_if.s_tx_axis_tlast) begin                                                
                                last_byte = 1'b1;
                                
                                if(tx_if.mii_select)
                                    @(posedge tx_if.clk);
                        end
                    end
     
                end
                CRC : begin
                    //Populate the CRC bytes after small delay
                    #1 if(tx_if.rgmii_mac_tx_dv) begin
                        tx_item.payload.push_back(tx_if.rgmii_mac_tx_data);                  
                        byte_ctr++;
                    end
                   
                    if(byte_ctr == 4) begin
                        state = IFG;
                        byte_ctr = 0;
                    end  
                end
                IFG : begin
                
                if(tx_if.mii_select)
                    @(posedge tx_if.clk);                
                
                //Wait for the IFG and send transaction item to scoreboard
                if(byte_ctr > 4'd12) begin 
                    state = IDLE;
                    copy_item = new("new_item");
                    copy_item.payload = tx_item.payload;  
                    
                    //foreach(copy_item.payload[i]) begin
                        //`uvm_info("MON", $sformatf("monitor data: %0h", copy_item.payload[i]), UVM_MEDIUM)
                    //end                    
                     
                    a_port.write(copy_item);                        
                    tx_item.payload.delete();  
                                                                  
                end else 
                    byte_ctr++;
                end
            endcase          
        end
    endtask : run_phase
    
endclass : tx_mac_monitor

`endif