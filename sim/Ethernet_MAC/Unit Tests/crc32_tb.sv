`timescale 1ns / 1ps

/*
 * This testbench simulates the basic sequential and combinational logic 
 * surrounding the CRC32 module. It employs a reference model that calculates 
 * the CRC32 for a stream of bytes based on a specific algorithm. The testbench 
 * compares the actual output of the design with the computed CRC32 value to ensure accuracy.
 */

module crc32_tb;

localparam DATA_WIDTH = 8;
localparam CRC_WIDTH = 32;
localparam TABLE_DEPTH = (2**DATA_WIDTH);
localparam POLY = 32'h04C11DB7;

/* Module Signal Declarations */
logic clk;
logic crc_en;
logic [DATA_WIDTH-1:0] i_byte;
logic [CRC_WIDTH-1:0] crc_out, o_crc_state, i_crc_state;

/* Module Instantiation */
crc32 #(.DATA_WIDTH(DATA_WIDTH)) crc32_DUT(.*);

/* Intermediate Signal Declarations */
logic [CRC_WIDTH-1:0] crc_lut [TABLE_DEPTH-1:0];            //LUT Decleration
logic [CRC_WIDTH-1:0] crc_state, crc_next;                  //these will be used to drive the i_crc_state and o_crc_state
logic reset_n, sof;                                         //Start of frame & Active low reset signal
logic [DATA_WIDTH-1:0] i_stream [];                         //Stores the packet to transmit
logic [DATA_WIDTH-1:0] i_data;                              //Stores byte from each packet to transmit
logic reset;

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
    
    /* Start of Frame to reset CRC State */
    sof = 1'b1;
    #10 sof = 1'b0;
    
    /* Enable CRC */
    @(posedge clk);
    crc_en = 1'b1;
    
    /* Drive each byte into the i_data reg, which will drive the data on the clock edge */ 
    foreach(i_byte_stream[i]) begin
        i_data = i_byte_stream[i];
        @(posedge clk);
    end
    
    /* After all Data has been driven disable crc */
    crc_en = 1'b0;

endtask : drive_crc32_data

/*** Logic to drive signals to the DUT ***/

/* Always block to manage crc_state */
always @(posedge clk) begin
    if (reset) begin
        crc_state <= 32'hFFFFFFFF;  // Reset CRC state to initial value
    end else if (crc_en) begin
        crc_state <= crc_next;      // Update CRC state on each clock cycle
        i_byte <= i_data;           //Drive data to module
    end
end

/* Combinational logic to update crc_next */
always_comb begin
    if (crc_en)
        crc_next = o_crc_state;     
    else
        crc_next = crc_state;      
end

assign i_crc_state = crc_state;
assign reset = (sof || ~reset_n);

//Init CRC LUT
initial begin
    $readmemb("C:/Users/klaze/Xilinx_FGPA_Projects/FPGA_Based_Network_Stack/Software/CRC_LUT.txt", crc_lut);
end

//Testbench Logic
initial begin
    //Init Signals
    sof = 1'b0;
    clk = 1'b0;
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
            else $fatal(2, "Actual output: %0h DID NOT match the reference model: %0h", crc_out, crc32_reference_model(i_stream));
    end
    
    $finish;
    
end

endmodule
