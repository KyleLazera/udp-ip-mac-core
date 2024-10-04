`timescale 1ns / 1ps
/*
 * The CRC32 module implements an algorithm based on Sarwate's method to parallelize the operation 
 * and improve overall latency. This algorithm leverages the linearity of CRCs, relying on the equation:
 * CRC(A ^ B) = CRC(A) ^ CRC(B). 
 *
 * The implementation utilizes a lookup table (LUT) containing precomputed CRC32 values for each byte,
 * ranging from 0 to 255. This LUT was populated using C code, which can be found in the Software directory.
 * Due to the use of the parallelized implementation instead of the serial implementation, the latency of 
 * the CRC algorithm is improved by a factor of 8. In the serial implementation, calculating the CRC32 for a byte 
 * takes 8x ns, where x is a clock cycle (bit-by-bit). However, this implementation allows a singular byte to 
 * be computed in x clock cycle(s). Therefore, to calculate the CRC for 10 bytes in the serial implementation 
 * would take: 8(10) = 80 clock cycles (each clock cycle is 8 ns, resulting in 640 ns). In contrast, the 
 * parallelized implementation takes only 10 clock cycles (80 ns).
 *
 * The algorithm is as follows:
 * 1) Invert the input byte so that the most significant bit becomes the least significant bit.
 * 2) XOR the input byte with the most significant bit (MSB) of the CRC state (initialized to 0xFFFFFFFF).
 * 3) Use this value as the index into the LUT (this will provide the precomputed CRC32 value for this byte).
 * 4) Shift the CRC state left by 8 bits (to make room for the new byte) and XOR with the output of the LUT.
 * 5) This is the new CRC state. If this was not the final byte, return to step 1.
 * 6) If this was the final byte, reverse the bits again and XOR them with 0xFFFFFFFF (invert).
 * 7) This is the output value.
 *
 * CRC Parameters:
 * - REFIN: Set to true, indicating that the input bits are reversed in the algorithm.
 * - REFOUT: Set to true, indicating that the final output bits are reversed.
 * - XOROUT: The final output value is XORed with 0xFFFFFFFF. In this module, it is implemented 
 *   simply by inverting the CRC state using the ~ operator.
 * - INIT: The CRC state is initialized to 0xFFFFFFFF, which is specified for Ethernet CRC32 calculations.
 * - POLY: The polynomial used is represented as:
 *     x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x^1 + 1
 *   or 0x04C11DB7 in hexadecimal.
 */

module crc32
#(
    parameter DATA_WIDTH = 8,                   // Input data width
    parameter CRC_WIDTH = 32,                   //Width of the CRC algorithm
    parameter POLY = 32'h04C11DB7               // CRC32 polynomial
)
(
    input wire clk,
    input wire reset,
    /* Input Signals */
    input wire [DATA_WIDTH-1:0] i_byte,         //Input Byte 
    input wire crc_en,                          //Enables the CRC indicating data has been passed in
    input wire eof,                             //End of frame signal - causes output CRC to be inverted & reversed
    /* Ouput Signals */             
    output wire [31:0] crc_out                  //Output CRC value
);

/* Local Parameters */
localparam TABLE_DEPTH = (2**DATA_WIDTH);
localparam TABLE_WIDTH = CRC_WIDTH;

/* Signal Declaratios */
reg [TABLE_WIDTH-1:0] crc_table [TABLE_DEPTH-1:0];      //Init LUT that holds precomputed CRC32 values for each byte value (0 - 255)
reg [CRC_WIDTH-1:0] crc_state, crc_next;                //Register that holds the state of the CRC
reg [DATA_WIDTH-1:0] i_byte_rev;                        //Used to reverse the bit order of the input byte
reg [CRC_WIDTH-1:0] o_crc_inv, o_crc_rev;               //Used for reversing and inverting the final CRC output value
reg [DATA_WIDTH-1:0] table_index;                       //Holds the index into the LUT

/* Initialize the LUT in ROM */
initial begin 
    $readmemb("C:/Users/klaze/Xilinx_FGPA_Projects/FPGA_Based_Network_Stack/Software/CRC_LUT.txt", crc_table);
end

/* Intermediary Logic */
always @(*) begin
    crc_next = crc_state;
    
    if(crc_en) begin
        //Reverse the input byte
        for(int i = 0; i < 8; i++) 
            i_byte_rev[i] = i_byte[(DATA_WIDTH-1)-i];  
        
        //Calculate Table index based on i_byte
        table_index = i_byte_rev ^ crc_state[31:24];
        //XOR output of LUT with teh current CRC state
        crc_next = {crc_state[24:0], 8'h0} ^ crc_table[table_index];    
    end
end

/* Invert and Reverse the CRC State - output used only when EOF is set */
generate 
    genvar j;
    //Invert the output CRC value
    assign o_crc_inv = ~crc_state;
    // Reverse the bit order for the output CRC
    for(j = 0; j < 32; j++) 
        assign o_crc_rev[j] = o_crc_inv[(CRC_WIDTH-1)-j]; 
        
endgenerate

/* Sequential Logic to update the CRC state */
always @(posedge clk) begin
    if(reset) 
        crc_state <= 32'hFFFFFFFF;
    else 
        crc_state <= crc_next;  
end

/* Output Logic */
assign crc_out = (eof) ? o_crc_rev : crc_state;

endmodule
