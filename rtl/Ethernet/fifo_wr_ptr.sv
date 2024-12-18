`timescale 1ns / 1ps


module fifo_wr_ptr
#(
    parameter ADDR_WIDTH,
    parameter ALMOST_FULL_DIFF    
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
    output reg [ADDR_WIDTH:0] w_ptr                //Write pointer that is used to compare to rd_ptr (In Grey Code)
);

/* Registers/Signals */
reg [ADDR_WIDTH:0] wr_ptr_bin, wr_ptr_bin_next;    //Registers the next write address calculated in binary
reg [ADDR_WIDTH:0] wr_ptr_grey;                    //Holds the grey code of the write pointer
reg [ADDR_WIDTH:0] rd_ptr_bin;                     //Holds binary version of rd_ptr (passed via grey code from write domain) 
reg [ADDR_WIDTH:0] wr_ptr_almost_full;             //Used to calculate the binary value for almsot full
reg full_next, almost_full_next;

/* Combinational Logic */

always @(*) begin
    rd_ptr_bin[ADDR_WIDTH] = rd_ptr[ADDR_WIDTH];
    
    for(int i = ADDR_WIDTH - 1; i >= 0; i--)                                        //Convert the rd_ptr from grey code to binary
        rd_ptr_bin[i] = rd_ptr_bin[i+1] ^ rd_ptr[i];
end

assign wr_ptr_bin_next = wr_ptr_bin + (write & !full);                              //Calculate teh next binary value for write address
assign wr_ptr_grey = (wr_ptr_bin_next >> 1) ^ wr_ptr_bin_next;                      //Convert binary value to grey code to synchronize into read domain

assign wr_ptr_almost_full = wr_ptr_bin_next + 4;                                    //Caluclate binary value that would indicate FIFO is almost full

assign full_next = (wr_ptr_grey == {~rd_ptr[ADDR_WIDTH:ADDR_WIDTH-1], rd_ptr[ADDR_WIDTH-2:0]});           
assign almost_full_next = (~wr_ptr_almost_full[ADDR_WIDTH:ADDR_WIDTH-1] == rd_ptr[ADDR_WIDTH:ADDR_WIDTH-1] &&
                            rd_ptr[ADDR_WIDTH-2:0] - wr_ptr_almost_full[ADDR_WIDTH-2:0] < ALMOST_FULL_DIFF);

/* Synchronous logic */
always @(posedge clk) begin
    if(!reset_n) begin
        wr_ptr_bin <= 0;
        w_ptr <= 0;
        full <= 1'b0;
        almost_full <= 1'b0;
    end else begin
        wr_ptr_bin <= wr_ptr_bin_next;
        w_ptr <= wr_ptr_grey;
        full <= full_next;
        almost_full <= almost_full_next;
    end
end

/* Output Logic */
assign w_addr = wr_ptr_bin[ADDR_WIDTH-1:0];

endmodule
