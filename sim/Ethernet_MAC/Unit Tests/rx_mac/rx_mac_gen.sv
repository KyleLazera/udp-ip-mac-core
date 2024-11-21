`ifndef _RX_MAC_GEN
`define _RX_MAC_GEN

/**********************************************
 * CRC32 Class
***********************************************/

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

`endif //_RX_MAC_GEN