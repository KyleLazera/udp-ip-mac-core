`timescale 1ns / 1ps

/*
 * Acts as the FIFO Wrapper, that encapsulates all the FIFO components into a singular module that interacts with
 * the rx and tx mac via AXI Stream.
*/

module fifo
#(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 255
)
(
    input wire clk_wr, clk_rd,
    input wire reset_n,
    
    /* Signals to Write Data to FIFO */
    input wire [DATA_WIDTH-1:0] data_in,
    input wire write_en,
    
    /* Signals to Read Data from FIFO */
    output wire [DATA_WIDTH-1:0] data_out,
    input wire read_en,
    
    /* Status Signals of FIFO */
    output wire empty,
    output wire full
);

/* Local Params */
localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);

/* Signals / Registers */
wire fifo_full, fifo_empty;
reg [ADDR_WIDTH-1:0] wr_addr, rd_addr;
reg [ADDR_WIDTH:0] wr_ptr_bin, wr_ptr_grey;
reg [ADDR_WIDTH:0] rd_ptr_bin, rd_ptr_grey;

/* Module Instantiations */

//FIFO Block RAM Instantiation
fifo_mem #(.DATA_WIDTH(DATA_WIDTH), .MEM_DEPTH(FIFO_DEPTH)) fifo_bram
        (.i_wr_clk(clk_wr), .i_rd_clk(clk_rd), .i_wr_en(write_en), .i_rd_en(read_en),
         .i_full(fifo_full), .i_wr_data(data_in), .o_rd_data(data_out), .i_wr_addr(wr_addr), .i_rd_addr(rd_addr));
         
//FIFO Write Pointer Comparator Instantiation
fifo_wr_ptr #(.ADDR_WIDTH(ADDR_WIDTH)) wr_ptr (.clk(clk_wr), .reset_n(reset_n), .write(write_en),
             .full(fifo_full), .rd_ptr(rd_ptr_grey), .w_addr(wr_addr), .w_ptr(wr_ptr_bin));

//FIFO Read Pointer Comparator Instantiation          
fifo_rd_ptr #(.ADDR_WIDTH(ADDR_WIDTH)) rd_ptr (.clk(clk_rd), .reset_n(reset_n), .read(read_en), .empty(fifo_empty), 
              .w_ptr(wr_ptr_grey), .rd_addr(rd_addr), .rd_ptr(rd_ptr_bin));
              
//Sychronize write clock domain data into read clock domain 
sync_w2r #(.ADDR_WIDTH(ADDR_WIDTH)) w2r_sync (.clk(clk_rd), .reset_n(reset_n), .i_wr_ptr(wr_ptr_bin), .o_wr_ptr(wr_ptr_grey));

//Synchronize read clock domain data into write clock domain
sync_r2w #(.ADDR_WIDTH(ADDR_WIDTH)) r2w_sync (.clk(clk_wr), .reset_n(reset_n), .i_rd_ptr(rd_ptr_bin), .o_rd_ptr(rd_ptr_grey));

/* Output signals */
assign full = fifo_full;
assign empty = fifo_empty;

endmodule
