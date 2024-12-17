`timescale 1ns / 1ps

/*
 * This module contains the double synchronizers used to synchronize the write/read pointer into the 
 * opposite clock domain. The pointers are passed in grey code format.
*/

module sync_w2r
#(parameter ADDR_WIDTH)
(
    input wire clk,
    input wire reset_n,
    
    /* Data to Synchronize */
    input wire [ADDR_WIDTH:0] i_wr_ptr,
    output wire [ADDR_WIDTH:0] o_wr_ptr
);

/* Signals/Registers */
reg [ADDR_WIDTH:0] wr_ptr_0, wr_ptr_1;

/* Sequential Logic */
always @(posedge clk) begin
    if(!reset_n) begin
        wr_ptr_0 <= 0;
        wr_ptr_1 <= 0;
    end else begin
        wr_ptr_1 <= wr_ptr_0;
        wr_ptr_0 <= i_wr_ptr;
    end
end

/* Output Logic */
assign o_wr_ptr = wr_ptr_1;

endmodule
