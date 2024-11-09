`ifndef _RX_MAC_GEN
`define _RX_MAC_GEN

/*
 * This file contains the classes that are used to generate a packet that will be sent to the rx_mac DUT.
 * The following goals guide the functionality of the class:
 * 1) Payload data has a randomized size (ranging from 46 to 1500) & randomized values.
 * 2) Each data valid (dv) transmission is randomized with probability distr: 1 = 99%, 0 = 1%
 * 3) Each data error (er) transmission is randomized with probability distr: 1 = 1%, 0 = 99%
 * 4) CRC for randomized data is calculated and appended to end of payload with randomized dv and er values
 * 5) Header + SFD is prepended to payload with associated dv and er values
*/

class crc32_checksum;
    /* Localparams */
    localparam DATA_WIDTH = 8;
    localparam CRC_WIDTH = 32;
    localparam TABLE_DEPTH = (2**DATA_WIDTH);
    
    /* Variables */
    logic [CRC_WIDTH-1:0] crc_lut [TABLE_DEPTH-1:0];    
    
    function new();
        //LUT Init
        $readmemb("C:/Users/klaze/Xilinx_FGPA_Projects/FPGA_Based_Network_Stack/Software/CRC_LUT.txt", crc_lut);
    endfunction : new
    
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
endclass : crc32_checksum

class rgmii_data;
    /* Variables */
    rand bit [7:0] data;                                        
    rand bit dv;
    rand bit er;      
    
    /* Constraints */   
    constraint rgmii_dv {dv dist {1 := 99, 0 := 1};}      //Distribution constraint for each dv
    constraint rgmii_er {er dist {1 := 1, 0 := 99};}      //Distribution constraint for each er                              
    
endclass : rgmii_data

class rx_packet extends rgmii_data;

    /* Localparams */
    localparam ETH_HDR = 8'h55;
    localparam ETH_SFD = 8'hD5; 
    
    /* Class Variables */
    rgmii_data packet [];                   //Packet to transmit from RGMII to MAC
    rand int pckt_size;
    rand int clk_prd;                       //Clock period for rgmii rxc
    
    /* Constraints */         
    constraint pckt_size_const {pckt_size inside {[10:15]};}               
    constraint clk_const {clk_prd dist {400 := 30, 40 := 35, 8 := 35};}  
    
    /* Constructor */
    function new();
        //Randomize the variables (clk period & packet size)
        assert(this.randomize) else $fatal(2, "Randomization Failed");    
      
        //Generate a packet 
        gen_packet();
   
    endfunction : new  

    /*
     * @brief This function generates data, dv and er values and places them into a singular packet that can be
     *          transmitted to the DUT.
     * @note The values are randomized accroding to specific constraints and depdning on the portion of the packet they belong to.
    */
    function gen_packet();
        logic [7:0] temp_payload []; 
        logic [31:0] crc_bytes;    
        
        //Init instance of CRC class
        crc32_checksum crc = new;
        //Init a temporary packet for CRC calculation
        temp_payload = new[pckt_size];
        //Init new instance of a packet with the specified size + header bytes (8) + CRC Bytes (4)
        packet = new[pckt_size + 8 + 4]; 
        
        /* Ethernet Header + SFD */
        for(int i = 0; i < 8; i++) begin
            packet[i] = new();
            
            if(i == 7)
                assert(packet[i].randomize with {packet[i].data == ETH_SFD;})
                    else $fatal(2, "Failed to meet header constraints");  
            else                                          
                assert(packet[i].randomize with {packet[i].data == ETH_HDR;})
                    else $fatal(2, "Failed to meet header constraints");
        end    
          
        /* Payload */
        for(int j = 0; j < pckt_size; j++) begin
            packet[j+8] = new();
            
            //Randomize each byte, dv and er value
            assert(packet[j+8].randomize()) 
                else $fatal(2, "Randomization failed for packet[%0d]", (j+8));            
            
            //copy this into the temp_payload array used for CRC calculation
            temp_payload[j] = packet[j+8].data;
        end       
        
        /* CRC */
        crc_bytes = crc.crc32_reference_model(temp_payload);
        $display("CRC: %0h", crc_bytes);
        
        for(int k = 0; k < 4; k++) begin
            packet[8 + pckt_size + k] = new();
            
            //Randomize dv and er and append calculated crc to packet
            assert(packet[8 + pckt_size + k].randomize() with {packet[8 + pckt_size + k].data == crc_bytes[(k*8) +: 8];}) 
                else $fatal(2, "Randomization failed for packet[%0d]", (8 + pckt_size + k));             
        end   
    endfunction : gen_packet

endclass : rx_packet


`endif //_RX_MAC_GEN