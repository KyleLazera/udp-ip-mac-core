`ifndef _RX_MAC_SEQ
`define _RX_MAC_SEQ

`include "rx_mac_gen.sv"

class rx_mac_seq extends uvm_sequence;
    /* Utility macros */
    `uvm_object_utils(rx_mac_seq)
    
    /* Localparams */
    localparam ETH_HDR = 8'h55;
    localparam ETH_SFD = 8'hD5; 
    localparam HEADER_SIZE = 8;
    localparam SFD_POS = 7;
    
    /* Instances of Helper Classes */
    rx_packet packet; 
    
    /* Class Variables */
    rand int pckt_size, num_pckts;          //Size of the payload in the packet & num of packets to be sent
    rand int clk_prd;                       //Clock period for rgmii rxc    
    
    /* Constraints */         
    constraint pckt_size_const {pckt_size inside {[49:1500]};}  
    constraint num_pckts_const {num_pckts inside{[1:3]};}             
    constraint clk_const {clk_prd dist {400 := 30, 40 := 35, 8 := 35};} 
    
    /* Constructor */
    function new(string name = "Gen_Item_Seq");
        super.new(name);
    endfunction : new    
    
    /* Main Function */
    virtual task body();
        //Init instance of CRC class -  This is used to calculate the CRC for the packet
        crc32_checksum crc = new;
    
        //Variables
        logic [7:0] temp_payload[];
        logic [31:0] crc_bytes; 
        
        //Loop to generate the specified number of packets
        for(int i = 0; i < num_pckts; i++) begin
            
            temp_payload = new[pckt_size];
            
            //Generate inidividual values within the packets (pckt_size + 8 header bytes + 4 CRC bytes)
            for(int j = 0; j < (pckt_size + HEADER_SIZE + 4); j++) begin
                //Create an instance of the sequence item
                rx_mac_rgmii_item m_item = rx_mac_rgmii_item::create("m_item");
                
                //Signal sequencer that transaction item is about to start
                start_item(m_item);
                
                /* Randomize the items here - They must be sent in an ethernet packet format */

                //Wait for the driver to indicate it has complete transmission
                finish_item(m_item);  
            end
        end
    endtask : body
   
    
endclass : rx_mac_seq    

`endif //_RX_MAC_SEQ
