`timescale 1ns / 1ps

/*
 * This module contains the instantiation of a simple dual-port Block RAM with 
 * dual clocks. 
 * Todo: Do calculatiosn to determine best size of the RAM
*/
module fifo_mem
#(
    DATA_WIDTH = 8,
    MEM_DEPTH = 64,
    ADDR_BITS = $clog2(MEM_DEPTH)
)
(
    input wire i_wr_clk,                                        //Clock for the write domain
    input wire i_rd_clk,                                        //Clock for the reading domain
    
    /* Control Signals */
    input wire i_wr_en, i_rd_en,                                //Enables reading/writing in each domain
    input wire i_full,                                          //Indicates the pointers are full
    
    /* Data from the Memory */
    input wire [DATA_WIDTH-1:0] i_wr_data,                      
    output reg [DATA_WIDTH-1:0] o_rd_data,
    
    /* Addresses calculated by FIFO components */
    input wire [ADDR_BITS-1:0] i_wr_addr, i_rd_addr
);

/* Register Declarations */
reg [DATA_WIDTH-1:0] dual_port_ram [0:MEM_DEPTH-1];

/* Synchronous Logic to write into Block RAM */
always@(posedge i_wr_clk) begin
    if(i_wr_en && !i_full) 
        dual_port_ram[i_wr_addr] <= i_wr_data;
end

//First work Fall through read of RAM
assign o_rd_data = dual_port_ram[i_rd_addr];

endmodule
