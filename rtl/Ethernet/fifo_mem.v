`timescale 1ns / 1ps

/*
 * This module contains the instantiation of a simple dual-port Block RAM with 
 * dual clocks. 
 * Todo: Do calculatiosn to determine best size of the RAM
*/
module fifo_mem
#(
    parameter FWFT = 1,
    parameter DATA_WIDTH = 8,
    parameter MEM_DEPTH = 64,
    parameter ADDR_BITS = $clog2(MEM_DEPTH)
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

/* Output BRAM reg used to improve timing budget */
reg [DATA_WIDTH-1:0] data_reg_pipeline;

/* Inferred BRAM Declaration */
(* ram_style="block" *) reg [DATA_WIDTH-1:0] dual_port_ram [0:MEM_DEPTH-1];

/* Synchronous Logic to write into Block RAM */
always@(posedge i_wr_clk) begin
    if(i_wr_en && !i_full) 
        dual_port_ram[i_wr_addr] <= i_wr_data;    
end

/////////////////////////////////////////////////////////////////////
// An extra FF is added on the read end of the FIFO to improve the timing
// budget. This FF should be inferred into the BRAM, and adds an extra 
// clock cycle delay of reading data out of the FIFO.
////////////////////////////////////////////////////////////////////////

generate 
    //If first word fall through is enabled, have teh output data always present 
    // on the data out line 
    if(FWFT == 1) begin
        always @(posedge i_rd_clk) begin
            data_reg_pipeline <= dual_port_ram[i_rd_addr];
        end
    //If FWFT is disabled, the user must drive rd_en high to pop the first word
    // off the FIFO
    end else 
        always @(posedge i_rd_clk) begin
            if(i_rd_en)
                data_reg_pipeline <= dual_port_ram[i_rd_addr];
        end    

endgenerate

assign o_rd_data = data_reg_pipeline;

endmodule
