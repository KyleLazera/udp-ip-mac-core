`timescale 1ns / 1ps
/*
 * The CRC32 module implements an algorithm based on Sarwate's method to parallelize the operation 
 * and improve overall latency. This algorithm leverages the linearity of CRCs, relying on the equation:
 * CRC(A ^ B) = CRC(A) ^ CRC(B). 
 *
 * Notes on Latency:
 * The implementation utilizes a lookup table (LUT) containing precomputed CRC32 values for each byte,
 * ranging from 0 to 255. This LUT was populated using C code, which can be found in the Software directory.
 * Unlike the serial implementation, which processes the CRC32 calculation bit-by-bit (resulting in a latency
 * of 8 clock cycles per byte), this implementation is fully parallelized, enabling the CRC32 computation for
 * a byte to be completed in a single clock cycle. Therefore, calculating the CRC for 10 bytes takes only
 * 10 clock cycles, dramatically reducing latency.
 *
 * In the serial implementation, calculating the CRC32 for a byte takes 8x ns, where x is a clock cycle (bit-by-bit).
 * For example, calculating the CRC32 for 10 bytes in the serial implementation would take: 8(10) = 80 clock cycles
 * (each clock cycle is 8 ns, resulting in 640 ns). In contrast, this parallelized implementation takes only
 * 10 clock cycles (80 ns). This means, 8 bits can be process in 8 ns (1 period), leading to 1 bit per ns. This ensures
 * Gbit processing.
 *
 * Algorithm:
 * 1. The input byte is inverted such that the most significant bit (MSB) becomes the least significant bit (LSB).
 * 2. The inverted input byte is XORed with the most significant byte of the input CRC state (which is initialized
 *    to `0xFFFFFFFF` for the first input).
 * 3. The result is used as an index into the LUT, providing the precomputed CRC32 value for this byte.
 * 4. The CRC state is shifted left by 8 bits (to make room for the new byte), and the result is XORed with the output
 *    of the LUT.
 * 5. This result becomes the updated CRC state. The module outputs the updated CRC32 value in the same clock cycle
 *    the input byte is received.
 *
 * Important Notes:
 * - The module processes the CRC32 calculation for a given input byte in purely combinational logic and outputs the
 *   updated CRC state on the same clock cycle as the input data.
 * - The CRC state must be input to the module and updated externally after each calculation to maintain correct operation
 *   across multiple bytes.
 * - This design enables high-speed, real-time processing, allowing the calculation of the CRC32 checksum at line rate
 *   for Gbit Ethernet applications.
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
    /* Input Signals */
    input wire [DATA_WIDTH-1:0] i_byte,         //Input Byte 
    input wire [CRC_WIDTH-1:0] i_crc_state,     //Input CRC State (this is initialized to 0xFFFFFFF or the output CRC State)
    input wire crc_en,                          //Enables the CRC indicating data has been passed in
    /* Ouput Signals */             
    output wire [CRC_WIDTH-1:0] crc_out,        //Output CRC value
    output wire [CRC_WIDTH-1:0] o_crc_state     //Outputs the current CRC State after a calculation
);

/* Local Parameters */
localparam TABLE_DEPTH = (2**DATA_WIDTH);
localparam TABLE_WIDTH = CRC_WIDTH;

/* Signal Declaratios */
reg [TABLE_WIDTH-1:0] crc_table [TABLE_DEPTH-1:0];      //Init LUT that holds precomputed CRC32 values for each byte value (0 - 255)
reg [DATA_WIDTH-1:0] i_byte_rev;                        //Used to reverse the bit order of the input byte
reg [CRC_WIDTH-1:0] o_crc_inv, o_crc_rev;               //Used for reversing and inverting the final CRC output value
reg [DATA_WIDTH-1:0] table_index;                       //Holds the index into the LUT
reg [CRC_WIDTH-1:0] crc_next;                           //Holds the next CRC calculation

/* Initialize the LUT in ROM */
initial begin 
    $readmemb("C:/Users/klaze/Xilinx_FGPA_Projects/FPGA_Based_Network_Stack/Software/CRC_LUT.txt", crc_table);
end

/* Intermediary Logic */
always @(*) begin   
        //Reverse the input byte
        for(int i = 0; i < 8; i++) 
            i_byte_rev[i] = i_byte[(DATA_WIDTH-1)-i];  
        
        //Calculate Table index based on i_byte
        table_index = i_byte_rev ^ i_crc_state[31:24];
        //XOR output of LUT with the current CRC state
        crc_next = {i_crc_state[24:0], 8'h0} ^ crc_table[table_index];          
end

/* Invert and Reverse the CRC State  */
generate 
    genvar j;
    //Invert the output CRC value
    assign o_crc_inv = ~crc_next;
    // Reverse the bit order for the output CRC
    for(j = 0; j < 32; j++) 
        assign o_crc_rev[j] = o_crc_inv[(CRC_WIDTH-1)-j];       
endgenerate


/* Output Logic */
assign o_crc_state = crc_next;
assign crc_out = o_crc_rev;

endmodule
