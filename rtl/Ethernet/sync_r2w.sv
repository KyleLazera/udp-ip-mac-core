`timescale 1ns / 1ps

/*
 * This module contains the double synchronizers used to synchronize the write/read pointer into the 
 * opposite clock domain. The pointers are passed in grey code format.
*/

module sync_r2w
#(parameter ADDR_WIDTH)
(
    input wire clk,
    input wire reset_n,
    
    /* Data to Synchronize */
    input wire [ADDR_WIDTH:0] i_rd_ptr,
    output wire [ADDR_WIDTH:0] o_rd_ptr
);

/* Signals/Registers */
(* async_reg="true", keep="true" *) reg [ADDR_WIDTH:0] rd_ptr_0, rd_ptr_1;

/* Sequential Logic */
always @(posedge clk) begin
    if(!reset_n) begin
        rd_ptr_0 <= 0;
        rd_ptr_1 <= 0;
    end else begin
        rd_ptr_1 <= rd_ptr_0;
        rd_ptr_0 <= i_rd_ptr;
    end
end

/* Output Logic */
assign o_rd_ptr = rd_ptr_1;

endmodule
