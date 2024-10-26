`ifndef _TX_MAC_SCB
`define _TX_MAC_SCB

`include "tx_mac_trans_item.sv"
`include "tx_mac_cfg.sv"

/* 
 * Scoreboard Checks:
 * 1) Ensure the preamble abides by the following pattern: 7 bytes of 8'h55 followed by 1 byte of 8'hD5
 * 2) Ensure the payload size is between 46 - 1500 bytes
 * 3) Use a reference model to confirm the CRC calclation
*/

class tx_mac_scb;
    localparam DATA_WIDTH = 8;
    localparam CRC_WIDTH = 32;
    localparam TABLE_DEPTH = (2**DATA_WIDTH);
    
    tx_mac_cfg cfg;
    //Mailbox from monitor
    mailbox scb_mbx;
    event scb_done;
    //LUT Declaration
    logic [CRC_WIDTH-1:0] crc_lut [TABLE_DEPTH-1:0];            
    //Tag for debugging/printing
    string TAG = "Scoreboard";
    //Variables for final scoreboard
    int header_fail = 0, payload_fail = 0, crc_fail = 0;
    int header_succ = 0, payload_succ = 0, crc_succ = 0;
    
    //Constructor
    function new(mailbox _mbx, event _evt);
        scb_mbx = _mbx;
        scb_done = _evt;
    endfunction : new
    
    task main();
        tx_mac_trans_item mon_item;
        //Variables
        int pckt_num = 0;
        $display("[%s] Starting...", TAG);
        
        //LUT Init
        $readmemb("C:/Users/klaze/Xilinx_FGPA_Projects/FPGA_Based_Network_Stack/Software/CRC_LUT.txt", crc_lut);
        
        forever begin
            //Fetch data from queue
            scb_mbx.get(mon_item);        
            
            /* Check Preamble Pattern */
            assert( {mon_item.preamble[0], mon_item.preamble[1], mon_item.preamble[2], mon_item.preamble[3], 
                    mon_item.preamble[4], mon_item.preamble[5], mon_item.preamble[6], mon_item.preamble[7]} 
                    == {{7{8'h55}}, 8'hD5} ) 
                    else begin
                        //Print the value that was picked up from the monitor 
                        $fatal(2, "[%s] Preamble mismatch: %0h", TAG,  {mon_item.preamble[0], mon_item.preamble[1], mon_item.preamble[2], mon_item.preamble[3], 
                        mon_item.preamble[4], mon_item.preamble[5], mon_item.preamble[6], mon_item.preamble[7]});
                        
                        //Increment the failed pckt
                        header_fail++;
                    end
            
            /* Check Payload Size is between 46 bytes and 1500 bytes*/
            assert(mon_item.payload.size() >= 46 && mon_item.payload.size() <= 1500) 
                else begin
                    $fatal(2, "[%s] Payload Size does not fall within range.", TAG);
                    //Increment payload fail
                    payload_fail++;
                end
                
            /* Check CRC Calculation */         
            assert(crc32_reference_model(mon_item.payload) == {mon_item.fcs[3], mon_item.fcs[2], mon_item.fcs[1], mon_item.fcs[0]})
                else begin
                    $fatal(2, "[%s] CRC-32 Failed. Reference model: %0h, DUT: %0h", TAG, crc32_reference_model(mon_item.payload), 
                            {mon_item.fcs[3], mon_item.fcs[2], mon_item.fcs[1], mon_item.fcs[0]});
                    foreach(mon_item.payload[i])
                        $display("0x%0h", mon_item.payload[i]);  
                    $fatal(2, "Faulty payload printed");                          
                    //increment crc fail
                    crc_fail++;
                end
                
            if(pckt_num == (cfg.num_pckt - 1)) begin               
                header_succ = (cfg.num_pckt - header_fail);
                payload_succ = (cfg.num_pckt - payload_succ);
                crc_succ = (cfg.num_pckt - crc_succ);
                ->scb_done;
            end else
                pckt_num++;
                
        end
                
    endtask : main
    
    
     /*
     * @Brief Reference Model that implements the CRC32 algorithm for each byte passed into it
     * @param i_byte Takes in a byte to pass into the model
     * @retval Returns the CRC32 current CRC value to append to the data message
    */
    function automatic [31:0] crc32_reference_model;
        input [7:0] i_byte_stream[];
        
        /* Intermediary Signals */
        reg [31:0] crc_state = 32'hFFFFFFFF;
        reg [31:0] crc_state_rev;
        reg [7:0] i_byte_rev, table_index;
        integer i;
        
        //Iterate through each byte in the stream
        foreach(i_byte_stream[i]) begin
             /* Reverse the bit order of the byte in question */
             i_byte_rev = 0;
             for(int j = 0; j < 8; j++)
                i_byte_rev[j] = i_byte_stream[i][(DATA_WIDTH-1)-j];
                
             /* XOR this value with the MSB of teh current CRC State */
             table_index = i_byte_rev ^ crc_state[31:24];
             
             /* Index into the LUT and XOR the output with the shifted CRC */
             crc_state = {crc_state[24:0], 8'h0} ^ crc_lut[table_index];
        end
        
        /* Reverse & Invert the final CRC State after all bytes have been iterated through */
        crc_state_rev = 32'h0;
        for(int k = 0; k < 32; k++) 
            crc_state_rev[k] = crc_state[(CRC_WIDTH-1)-k];
        
        crc32_reference_model = ~crc_state_rev;
        
    endfunction : crc32_reference_model   
    
    function void display_score();
        $display("****************************************");
        $display("Final Score Board: ");
        $display("MII Select Value: %0d (1 indicates 10/100 mbps, 0 indicates 1 gbit)", cfg.mii_sel);
        $display("Total Packets Transmitted: %0d", cfg.num_pckt);
        $display("Number of Succesfull Headers: %0d Number of Failed Headers: %0d", header_succ, header_fail);
        $display("Number of Succesfull Payloads: %0d Number of Failed Payloads: %0d", payload_succ, payload_fail);
        $display("Number of Succesfull CRC's: %0d Number of Failed CRC's: %0d", crc_succ, crc_fail);        
    endfunction

endclass : tx_mac_scb

`endif