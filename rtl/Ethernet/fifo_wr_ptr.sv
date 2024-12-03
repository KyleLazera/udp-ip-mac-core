`timescale 1ns / 1ps


module fifo_wr_ptr
#(parameter ADDR_WIDTH)
(
    input wire clk,
    input wire reset_n,
    
    /* Control/Status Signals */
    input wire write,                               //Signal to indicate the FIFO is being written to
    output reg full,                                //Signal to indicate FIFO is full
    
    /* Address Pointers */
    input wire [ADDR_WIDTH:0] rd_ptr,              //Read pointer that is passed from read clock domain (arrived in grey code)
    output reg [ADDR_WIDTH-1:0] w_addr,            //Write address that is used for the FIFO memory (In Binary)
    output reg [ADDR_WIDTH:0] w_ptr                //Write pointer that is used to compare to rd_ptr (In Grey Code)
);

/* Registers/Signals */
reg [ADDR_WIDTH:0] bin, bnext;                     //Holds the next binary value calculated
reg [ADDR_WIDTH:0] gnext;                          //Holds the grey code version of the binary value
reg full_next;

/* Combinational Logic */
assign bnext = bin + (write & !full);
assign gnext = (bnext >> 1) ^ bnext;
assign full_next = (gnext == {~rd_ptr[ADDR_WIDTH:ADDR_WIDTH-1], rd_ptr[ADDR_WIDTH-2:0]});

/* Synchronous logic */
always @(posedge clk) begin
    if(!reset_n) begin
        bin <= 0;
        w_ptr <= 0;
        full <= 1'b0;
    end else begin
        bin <= bnext;
        w_ptr <= gnext;
        full <= full_next;
    end
end

/* Output Logic */
assign w_addr = bin[ADDR_WIDTH-1:0];

endmodule
