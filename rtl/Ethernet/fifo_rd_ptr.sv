`timescale 1ns / 1ps


module fifo_rd_ptr
#(
    parameter ADDR_WIDTH,
    parameter ALMOST_EMPTY_DIFF    
)
(
    input wire clk,
    input wire reset_n,
    
    /* Control/Status Signals */
    input wire read,                               //Signal to indicate the FIFO is being read from
    output reg empty,                               //Signal to indicate FIFO is empty
    output reg almost_empty,                        //Signal indicating FIFO is almost empty
    
    /* Address Pointers */
    input wire [ADDR_WIDTH:0] w_ptr,               //Write pointer that is passed from write clock domain (arrived in grey code)
    output reg [ADDR_WIDTH-1:0] rd_addr,           //Read address that is used for the FIFO memory (In Binary)
    output reg [ADDR_WIDTH:0] rd_ptr               //Read pointer that is passed to the write clock domain (In Grey Code)
);

/* Signals/Registers */
reg [ADDR_WIDTH:0] rd_ptr_bin, rd_ptr_bin_next;    //Registers the value of the next read address (In Binary)
reg [ADDR_WIDTH:0] rd_ptr_grey;                    //Holds grey code version of read pointer
reg [ADDR_WIDTH:0] wr_ptr_bin;                     //Holds the binary version of the write pointer passed from read clock domain
reg [ADDR_WIDTH:0] rd_ptr_almost_empty;            //Calculate the almost empty value 
reg empty_next, almost_empty_next;

/* Combinational Logic */

always @(*) begin
    wr_ptr_bin[ADDR_WIDTH] = w_ptr[ADDR_WIDTH];
    
    for(int i = ADDR_WIDTH - 1; i >= 0; i--) 
        wr_ptr_bin[i] = wr_ptr_bin[i + 1] ^ w_ptr[i];                           //Convert the grey code wr_ptr to binary 
end

assign rd_ptr_bin_next = rd_ptr_bin + (read & !empty);                          //Calculate the next read pointer
assign rd_ptr_grey = (rd_ptr_bin_next >> 1) ^ rd_ptr_bin_next;                  //Convert the read pointer to grey code
assign rd_ptr_almost_empty = rd_ptr_bin_next + ALMOST_EMPTY_DIFF;               //Caluclate the almost empty value

assign empty_next = (rd_ptr_grey == w_ptr);                                     //Compare the recieved write pointer with the grey code read pointer

/* Logic to check if FIFO is almost empty */
assign almost_empty_next = (wr_ptr_bin >= rd_ptr_bin_next) ? (wr_ptr_bin - rd_ptr_bin_next < ALMOST_EMPTY_DIFF)
                : (rd_ptr_almost_empty >= wr_ptr_bin);                 

/* Synchronous Logic */
always @(posedge clk) begin
    if(!reset_n) begin
        rd_ptr_bin <= 0;
        rd_ptr <= 0;
        empty <= 1'b1;
        almost_empty <= 1'b1;
    end else begin
        rd_ptr_bin <= rd_ptr_bin_next;
        rd_ptr <= rd_ptr_grey;
        empty <= empty_next;
        almost_empty <= almost_empty_next;
    end
end

/* Output Logic */
assign rd_addr = rd_ptr_bin[ADDR_WIDTH-1:0];

endmodule
