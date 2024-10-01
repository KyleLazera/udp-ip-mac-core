`timescale 1ns / 1ps


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
reg [DATA_WIDTH-1:0] table_index;                      //Holds the index into the LUT

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
