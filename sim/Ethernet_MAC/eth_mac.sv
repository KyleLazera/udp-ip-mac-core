`ifndef ETH_MAC
`define ETH_MAC

`include "uvm_macros.svh"  // Import UVM macros
import uvm_pkg::*;         // Import all UVM classes

class eth_mac extends uvm_object;
    `uvm_object_utils(eth_mac)

    /*Parameters */
    localparam DATA_WIDTH = 8;
    localparam CRC_WIDTH = 32;
    localparam TABLE_DEPTH = (2**DATA_WIDTH);
    localparam PADDING = 8'h00;
    localparam MIN_BYTES = 60;
    localparam HDR = 8'h55;
    localparam SFD = 8'hD5; 
    typedef logic [7:0] data_packet[$]; 

    /* Variables */
    bit [CRC_WIDTH-1:0] crc_lut [TABLE_DEPTH-1:0];       

    function new(string name = "eth_mac");
        super.new(name);
        $readmemb("C:/Users/klaze/Xilinx_FGPA_Projects/FPGA_Based_Network_Stack/Software/CRC_LUT.txt", crc_lut);
    endfunction : new

    //Fnction that calculates the crc32 for the input data
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
    
    //Function that encapsulates teh data into an etehrnet frame
    function void encapsulate_data(ref bit [7:0] driver_data[$]);
        
        int packet_size;
        logic [31:0] crc;
        //Reverse teh endianess
        driver_data =  {<<8{driver_data}};        

        packet_size = driver_data.size();
        `uvm_info("encap_data", $sformatf("Packet size: %0d", packet_size), UVM_MEDIUM)
        //If the packet had less than 60 bytes, we need to pad it
        while(packet_size < MIN_BYTES) begin
            driver_data.push_back(PADDING);
            packet_size++;
        end

        //Calculate the CRC for the Payload & append to the back
        crc = crc32_reference_model(driver_data);
        `uvm_info("encap_data", $sformatf("CRC: %0h", crc), UVM_MEDIUM)
        for(int i = 0; i < 4; i++) begin
            driver_data.push_back(crc[i*8 +: 8]);
        end

        //Prepend the header & SFD
        for(int i = 7; i >= 0; i--) begin    
            if(i == 7)
                driver_data.push_front(SFD);
            else
                driver_data.push_front(HDR);
        end         
        
        foreach(driver_data[i])
            `uvm_info("encap_data", $sformatf("Encapsulated Data: %0h", driver_data[i]), UVM_HIGH)          

    endfunction       

endclass : eth_mac

`endif //ETH_MAC