`ifndef _RX_MAC_SEQ
`define _RX_MAC_SEQ

//`include "rx_mac_gen.sv"
`include "rx_mac_packet.sv"

class rx_mac_seq extends uvm_sequence;
    /* Utility macros */
    `uvm_object_utils(rx_mac_seq)
    
    /* Class Variables */
    rand int num_pckts;                     //Num of packets to be sent
    rand int clk_prd;                       //Clock period for rgmii rxc    
    
    /* Constraints */         
    constraint num_pckts_const {num_pckts inside{[1:3]};}             
    constraint clk_const {clk_prd dist {400 := 30, 40 := 35, 8 := 35};} 
    
    /* Constructor */
    function new(string name = "Gen_Item_Seq");
        super.new(name);
    endfunction : new    
    
    /* Main Function */
    virtual task body();

     //Loop to generate the specified number of packets
        for(int i = 0; i < num_pckts; i++) begin            
            //Create an instance of the packet generation class
            rx_eth_packet ethernet_packet = rx_eth_packet::type_id::create($sformatf("eth packet %0d", i));          
            
            //Generate the packet to transmit (important for correct formatting)
            ethernet_packet.generate_packet();
            
            //Send each item of the packet to the driver
            foreach(ethernet_packet.packet[i]) begin
                //Signal sequencer that transaction item is ready
                start_item(ethernet_packet.packet[i]);
                
                //Wait for the driver to indicate it has complete transmission
                finish_item(ethernet_packet.packet[i]);                                 
            end             
        end
    endtask : body
       
endclass : rx_mac_seq    

`endif //_RX_MAC_SEQ
