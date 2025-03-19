`timescale 1ns / 1ps

module fifo_wr_ptr
#(
    parameter ADDR_WIDTH = 8,
    parameter ALMOST_FULL_DIFF = 50   
)
(
    input wire clk,
    input wire reset_n,
    
    /* Control/Status Signals */
    input wire write,                               //Signal to indicate the FIFO is being written to
    output reg full,                                //Signal to indicate FIFO is full
    output reg almost_full,                         //Signal indicating the FIFO is almost full
    
    /* Address Pointers */
    input wire [ADDR_WIDTH:0] rd_ptr,              //Read pointer that is passed from read clock domain (arrived in grey code)
    output reg [ADDR_WIDTH-1:0] w_addr,            //Write address that is used for the FIFO memory (In Binary)
    output reg [ADDR_WIDTH:0] w_ptr,               //Write pointer that is used to compare to rd_ptr (In Grey Code)

    /* FIFO Bad Packet signals */
    input wire drop_pckt,                          //indicates a bad packet was identified and needs to be dropped
    input wire latch_addr                          //Latches the current write address
);

/* Registers/Signals */
reg [ADDR_WIDTH:0] wr_ptr_bin, wr_ptr_bin_next;    //Registers the next write address calculated in binary
reg [ADDR_WIDTH:0] wr_ptr_grey;                    //Holds the grey code of the write pointer
reg [ADDR_WIDTH:0] rd_ptr_bin;                     //Holds binary version of rd_ptr (passed via grey code from write domain) 
reg [ADDR_WIDTH:0] wr_ptr_almost_full;             //Used to calculate the binary value for almsot full
reg full_next, almost_full_next;

reg [ADDR_WIDTH:0] temp_wr_ptr = {ADDR_WIDTH{1'b0}};

/* Combinational Logic */

//Convert the incoming grey coded read pointer to binary to compute the almost full flag
always @(*) begin
    rd_ptr_bin[ADDR_WIDTH] = rd_ptr[ADDR_WIDTH];
    
    for(int i = ADDR_WIDTH - 1; i >= 0; i--)                      
        rd_ptr_bin[i] = rd_ptr_bin[i+1] ^ rd_ptr[i];
end

//Caluclate next wr_ptr and convert to grey code so it can be sent to the read clock domain for comparison
assign wr_ptr_bin_next = wr_ptr_bin + (write & !full);                              
assign wr_ptr_grey = (wr_ptr_bin_next >> 1) ^ wr_ptr_bin_next;                      

//Caluclate binary value of the address with the almost full threshold added
assign wr_ptr_almost_full = wr_ptr_bin_next + ALMOST_FULL_DIFF;                                    

//Full Flag Logic
assign full_next = (wr_ptr_grey == {~rd_ptr[ADDR_WIDTH:ADDR_WIDTH-1], rd_ptr[ADDR_WIDTH-2:0]}); 

//Almost Full Flag Logic          
assign almost_full_next = (~wr_ptr_almost_full[ADDR_WIDTH] == rd_ptr_bin[ADDR_WIDTH] &&
                           wr_ptr_almost_full[ADDR_WIDTH-1:0] >= rd_ptr_bin[ADDR_WIDTH-1:0]);

/* Synchronous logic */
always @(posedge clk) begin
    if(!reset_n) begin
        wr_ptr_bin <= 0;
        w_ptr <= 0;
        full <= 1'b0;
        almost_full <= 1'b0;
    end else begin
        wr_ptr_bin <= (drop_pckt) ? temp_wr_ptr : wr_ptr_bin_next;
        w_ptr <= wr_ptr_grey;
        full <= full_next;
        almost_full <= almost_full_next;
    end
end

////////////////////////////////////////////////////////////////////////////////////////
// This specific to the ethernet MAC. Since the MAC operates packet-wise, data should 
// only be read from the FIFO when a full, valid packet has been written into the FIFO.
// Specifically for the rx MAC side, there is a chance that the rx MAC writes majority 
// of a packet into the FIFO, however, there is a bad CRC or some other signal indicating
// a bad packet. This packet now needs to be dropped and we do not want to store this in 
// the FIFO. The following logic addresses this issue:
// Everytime a valid packet is written in (tlast without tuser being raised), the latch_addr
// signal is set temporarily high and teh next write address is saved. This address will
// be saved until the next valid packet (tlast & !tuser). If tuser goes high at any point,
// drop packet is raised and the write address is reset back to the saved write address.
///////////////////////////////////////////////////////////////////////////////////////////
always @(posedge clk) begin
    if(!reset_n)
        temp_wr_ptr <= {ADDR_WIDTH{1'b0}};
    else if(latch_addr)
        temp_wr_ptr <= wr_ptr_bin + 1'b1;
    else
       temp_wr_ptr <= temp_wr_ptr;
end

/* Output Logic */
assign w_addr = wr_ptr_bin[ADDR_WIDTH-1:0];

endmodule
