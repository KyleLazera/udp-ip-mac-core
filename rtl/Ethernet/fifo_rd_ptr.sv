`timescale 1ns / 1ps


module fifo_rd_ptr
#(parameter ADDR_WIDTH)
(
    input wire clk,
    input wire reset_n,
    
    /* Control/Status Signals */
    input wire read,                               //Signal to indicate the FIFO is being read from
    output reg empty,                               //Signal to indicate FIFO is empty
    
    /* Address Pointers */
    input wire [ADDR_WIDTH:0] w_ptr,               //Write pointer that is passed from write clock domain (arrived in grey code)
    output reg [ADDR_WIDTH-1:0] rd_addr,           //Read address that is used for the FIFO memory (In Binary)
    output reg [ADDR_WIDTH:0] rd_ptr               //Read pointer that is used to compare to w_ptr (In Grey Code)
);

/* Signals/Registers */
reg [ADDR_WIDTH:0] bin, bnext;
reg [ADDR_WIDTH:0] gnext;
reg empty_next;

/* Combinational Logic */
assign bnext = bin + (read & !empty);               //Calculate the next read pointer
assign gnext = (bnext >> 1) ^ bnext;                //Convert the read pointer to grey code
assign empty_next = (gnext == w_ptr);

/* Synchronous Logic */
always @(posedge clk) begin
    if(!reset_n) begin
        bin <= 0;
        rd_ptr <= 0;
        empty <= 1'b1;
    end else begin
        bin <= bnext;
        rd_ptr <= gnext;
        empty <= empty_next;
    end
end

/* Output Logic */
assign rd_addr = bin[ADDR_WIDTH-1:0];

endmodule
