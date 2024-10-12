`ifndef _TX_MAC_MONITOR
`define _TX_MAC_MONITOR

`include "tx_mac_trans_item.sv"

class tx_mac_monitor;
    /* Class variables */
    mailbox scb_mbx;                //Mailbox for scoreboard communication
    virtual tx_mac_if vif;          //Virtual interface
    string TAG = "Monitor";         //Tag for debugging/printing
    
    typedef enum {IDLE,             //Initial waiting state
                  PREAMBLE,         //Check the preamble
                  PAYLOAD,          //Check the payload
                  CRC,              //Check teh CRC/FCS
                  IFG               //IFG before next packet
                  }state_type;
                     
    //Constructor
    function new(mailbox _mbx);
        scb_mbx = _mbx;
    endfunction : new  
    
    task main();
        /* Monitor Variables */
        tx_mac_trans_item rec_item = new;

        state_type state = IDLE;
        int byte_ctr = 0;
        bit last_byte = 1'b0;
        
        logic [7:0] ethernet_pckt[$];
        //Queue to hold the preamble/SFD
        logic [7:0] preamble [$];         
        
        $display("[%s] Starting...", TAG);
        
        forever begin
            //Sample the data being transmitted to the RGMII on every clock pulse
            @(posedge vif.clk);  
            
            case(state)
                IDLE : begin
                    //If there is valid data in the FIFO go to the preamble state
                    if(vif.s_tx_axis_tvalid)
                        state = PREAMBLE;
                end
                PREAMBLE : begin
                    if(byte_ctr < 7) begin
                        #1 rec_item.preamble[byte_ctr] = vif.rgmii_mac_tx_data;
                        byte_ctr++;
                    end else begin
                        #1 rec_item.preamble[byte_ctr] = vif.rgmii_mac_tx_data;
                        byte_ctr = 0;
                        state = PAYLOAD;
                    end 
                                                                                       
                end
                PAYLOAD : begin                                    
                    #1 rec_item.payload.push_back(vif.rgmii_mac_tx_data);                    
                    byte_ctr++;
                    
                    if(last_byte && byte_ctr > 59) begin
                        last_byte = 1'b0;
                        state = CRC;
                        byte_ctr = 0;
                    end else begin                                                
                        if(vif.s_tx_axis_tlast) begin
                            last_byte = 1'b1;
                        end
                    end
                                        
                    
                end
                CRC : begin
                    //Populate the CRC bytes after small delay
                    #1;
                    case(byte_ctr)
                        0 : rec_item.fcs[0] = vif.rgmii_mac_tx_data;
                        1 : rec_item.fcs[1] = vif.rgmii_mac_tx_data;
                        2 : rec_item.fcs[2] = vif.rgmii_mac_tx_data;
                        3 : rec_item.fcs[3] = vif.rgmii_mac_tx_data;
                    endcase
                   
                    if(byte_ctr == 3) begin
                        state = IFG;
                        byte_ctr = 0;
                    end else
                        byte_ctr++;
                   
                end
                IFG : begin
                //Wait for the IFG and send transaction item to scoreboard
                if(byte_ctr > 4'd12) begin 
                    state = IDLE;
                    scb_mbx.put(rec_item);                    
                end else 
                    byte_ctr++;
                end
            endcase                             
        end
        
    endtask : main 
  
    
endclass : tx_mac_monitor

`endif
