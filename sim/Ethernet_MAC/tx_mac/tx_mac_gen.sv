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
        //Generate 10 packets to transmit (adjust this to more)
        for(int j = 0; j < cfg.num_pckt; j++) begin
            //Used to randomize teh size of the packet
            gen_item.pckt_size = $urandom_range(30, 1500);        
          
            //Generate the number of bytes based on the packet size
            for(int i = 0; i < gen_item.pckt_size; i++) begin
                //Randomize the byte value
                gen_item.randomize(data_byte);
                //Send the byte to the driver
                drv_mbx.put(gen_item);
                //Wait for driver to indicate it has transmitted the byte
                @(drv_done);
            end
        end
        @(scb_done);
        
        $display("Generator Complete");
        
    endtask : main
    
endclass : tx_mac_gen

`endif// _MAC_TX_GEN