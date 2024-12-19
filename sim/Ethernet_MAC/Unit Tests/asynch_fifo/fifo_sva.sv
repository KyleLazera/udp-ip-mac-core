`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/19/2024 08:53:21 AM
// Design Name: 
// Module Name: fifo_sva
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fifo_sva
#(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 256
)
(
    input logic clk_wr, clk_rd,
    input logic reset_n,
    input logic [DATA_WIDTH-1:0] data_in,
    input logic write_en,
    input logic [DATA_WIDTH-1:0] data_out,
    input logic read_en,
    input logic empty,
    input logic almost_empty,
    input logic full,
    input logic almost_full
);

/* Properties */

//If the full flag is raised, teh almost_full flag should also be raised
property full_and_almost_full;
@(posedge clk_wr) disable iff(~reset_n)
    full |-> almost_full;
endproperty : full_and_almost_full

//if the empty flag is raised, the almost_empty flag shoudl also be raised
property empty_and_almost_empty;
@(posedge clk_rd) disable iff(~reset_n)
    empty |-> almost_empty;    
endproperty : empty_and_almost_empty

/* Concurrent Assertions */

assert property(full_and_almost_full) else $display("Almost_full flag was not asserted while full flag was asserted");

assert property(empty_and_almost_empty) else $display("Almost_empty flag was not asserted while empty flag was asserted");

endmodule
