`timescale 1ns / 1ps
`ifndef _MAC_TX_GEN
`define _MAC_TX_GEN

//Include transaction Item class
`include "tx_mac_trans_item.sv"
`include "tx_mac_cfg.sv"

class tx_mac_gen;
    //Configuration for test
    tx_mac_cfg cfg;
    //Mailbox to communicate with driver
    mailbox drv_mbx;
    //Used to control flow of generator from driver & scb
    event drv_done, scb_done;
    //Tag for printing/debugging
    string TAG = "Generator";
    //Variables  
    local logic [7:0] data_byte;
    local int pckt_size;
     
    
    //Constructor    
    function new(mailbox _drv_mbx, event _evt_drv, event _evt_scb);
        drv_mbx = _drv_mbx;
        drv_done = _evt_drv;
        scb_done = _evt_scb;
    endfunction : new
    
    task main();
        //Create an instance of teh transaction item that will be sent to teh driver
        tx_mac_trans_item gen_item = new(); 
        $display("[%s] Starting...", TAG);   
        $display("[%s] Number of Packets to transmit: %0d", TAG, cfg.num_pckt);

        for(int j = 0; j < cfg.num_pckt; j++) begin
            /* Randomize the num of bytes in the packet */                        
            pckt_size = $urandom_range(20, 1500);                   
          
            //Generate the number of bytes based on the packet size
            for(int i = 0; i < pckt_size; i++) begin
                /* Randomize the byte value */
                data_byte = $urandom_range(0, 255);
                
                /* Push the value to back of the queue */
                gen_item.payload.push_back(data_byte);
                
                /* Populate the last byte queue if we are on last iteration*/
                if(i == (pckt_size - 1))
                    gen_item.last_byte.push_back(1'b1);
                else
                    gen_item.last_byte.push_back(1'b0);
            end
            
            //Ensure the last byte and payload are same size
            assert(gen_item.last_byte.size() == gen_item.payload.size()) 
                else $fatal(2, "Size mismatch for last byte and payload queue");
            
            //Send the full fifo & last byte queue to the driver
            drv_mbx.put(gen_item);
            //Wait for driver to indicate it has transmitted packet
            @(drv_done);
            
            // Empty the queue before next packet
            gen_item.payload.delete();
            gen_item.last_byte.delete();
        
        end
        // Wait for scoreboard to complete processing
        @(scb_done);
        
        $display("[%s] Generator Complete", TAG);
        
    endtask : main
    
endclass : tx_mac_gen

`endif// _MAC_TX_GEN