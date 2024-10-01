`timescale 1ns / 1ps

module crc32_tb;

localparam DATA_WIDTH = 8;
localparam CRC_WIDTH = 32;
localparam TABLE_DEPTH = (2**DATA_WIDTH);
localparam POLY = 32'h04C11DB7;

/* Module Signal Declarations */
logic clk;
logic reset;
logic eof;
logic crc_en;
logic [DATA_WIDTH-1:0] i_byte;
logic crc_done;
logic [CRC_WIDTH-1:0] crc_out;

/* Module Instantiation */
crc32 #(.DATA_WIDTH(DATA_WIDTH)) crc32_DUT(.*);

/* Intermediate Signal Declarations */
logic [CRC_WIDTH-1:0] crc_lut [TABLE_DEPTH-1:0];            //LUT Decleration
logic sof, reset_n;                                         //Start of frame & Active low reset signal

//Clock instantiation
always #4 clk = ~clk;


/********* Function & Task Declarations ***********/

/*
 * @brief Function used to generate a packet with random values
 * @note The packet is constrained to a random size (64 - 1500 bytes)
 * @param packet This is the input packet that is adjusted by reference 
*/
function void generate_packet;
    output logic [7:0] packet[];
    int packet_size;
    int i;
    
    /* First rnaomdize teh size of the packet ensuring it is between 64 and 1500 bytes */
    packet_size = $urandom_range(64, 1500);
    packet = new[packet_size];
    
    /* Randomize the values inside the packet */
    foreach(packet[i])
        packet[i] = $urandom_range(0, 255);
   
endfunction : generate_packet

/*
 * @Brief Reference Model that implements the CRC32 algorithm based on the LUT
 * @param i_byte_stream Takes in the stream of bytes to pass into the model
 * @retval Returns the CRC32 value to append to the data message
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

/*
 * @brief Controls the flow of data into the DUT
 * @param i_byte_stream Stream of bytes to pass into the DUT
*/
task drive_crc32_data;
    input logic [7:0] i_byte_stream[];
    integer i;
    
    /* Set SOF to indciate start of a new frame and reset CRC state*/
    sof = 1'b1;
    
    /* Enable CRC and disable SOF */
    @(posedge clk);
    sof = 1'b0;
    crc_en = 1'b1;
    eof = 1'b0;
    
    /* Drive each byte on a rising clock edge */ 
    foreach(i_byte_stream[i]) begin
        i_byte = i_byte_stream[i];
        @(posedge clk);
    end
    
    /* After all Data has been driven pull eof high and disable crc */
    eof = 1'b1;
    crc_en = 1'b0;
    @(posedge clk);

endtask : drive_crc32_data

assign reset = (sof || ~reset_n);
logic [7:0] i_stream [];

//Init CRC LUT
initial begin
    $readmemb("C:/Users/klaze/Xilinx_FGPA_Projects/FPGA_Based_Network_Stack/Software/CRC_LUT.txt", crc_lut);
end

//Testbench Logic
initial begin
    //Init Signals
    clk = 1'b0;
    eof = 1'b0;
    reset_n = 1'b0;
    #50;
    reset_n = 1'b1;
      
    //Generate 50 packets to transmit to the CRC32
    for(int i = 0; i < 50; i++) begin
        /* Generate Random Packet to Transmit */
        generate_packet(i_stream);
        
        /* Drive Packet into DUT */
        drive_crc32_data(i_stream);
        
        /* Compare output to reference model */
        assert(crc_out == crc32_reference_model(i_stream)) 
            else $fatal("Actual output DID NOT match the reference model");
    end
    
    $finish;
    
end

endmodule
