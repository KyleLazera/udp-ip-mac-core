`timescale 1ns / 1ps

/*
 * This module serves as the FIFO Wrapper, encapsulating all FIFO components into a single module that interfaces 
 * with the RX and TX MAC via AXI Stream.
 *
 * Note: This FIFO uses "pessimistic" full and empty flags. While the flags are asserted at the correct time, 
 * they experience a 2-clock-cycle delay in deassertion. This delay is caused by the need to synchronize the pointer 
 * from the opposite clock domain into the current clock domain using two synchronizer flip-flops.
 * 
 * Note: Due to clock synchronization delays, during sequential read and write operations, a full or empty flag 
 * might be erroneously raised if the flag comparison occurs before the data from the other clock domain is updated. 
 * To address this, almost full and almost empty flags are incorporated for more accurate status signaling.
 */


module fifo
#(
    parameter FWFT = 1,                 //Determines whether the FIFO operates in First Word Fall Through mode (FWFT = 1)
                                        // or if the rd_en signal must be driven to pop teh first byte of data (FWFT = 0)

    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 256
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
    output wire almost_empty,
    output wire full,
    output wire almost_full,

    /* FIFO Bad Packet signals */
    input wire drop_pckt,                          //indicates a bad packet was identified and needs to be dropped
    input wire latch_addr                          //Latches the current write address    
);

/* Local Params */
//localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);
localparam ADDR_WIDTH = logb2(FIFO_DEPTH);

function integer logb2(input integer depth);
    integer int_depth;

    begin
        int_depth = (depth > 1) ? depth - 1 : depth;
        for(logb2 = 0; int_depth > 0; logb2 = logb2 + 1)
            int_depth = int_depth >> 1;
    end
endfunction : logb2

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
fifo_wr_ptr #(.ADDR_WIDTH(ADDR_WIDTH), .ALMOST_FULL_DIFF(50)) wr_ptr (.clk(clk_wr), .reset_n(reset_n), .write(write_en),
             .full(fifo_full), .rd_ptr(rd_ptr_grey), .w_addr(wr_addr), .w_ptr(wr_ptr_bin), .almost_full(almost_full), 
             .drop_pckt(drop_pckt), .latch_addr(latch_addr));

//FIFO Read Pointer Comparator Instantiation          
fifo_rd_ptr #(.ADDR_WIDTH(ADDR_WIDTH), .ALMOST_EMPTY_DIFF(50)) rd_ptr (.clk(clk_rd), .reset_n(reset_n), .read(read_en), .empty(fifo_empty), 
              .w_ptr(wr_ptr_grey), .rd_addr(rd_addr), .rd_ptr(rd_ptr_bin), .almost_empty(almost_empty));
              
//Sychronize write clock domain data into read clock domain 
sync_w2r #(.ADDR_WIDTH(ADDR_WIDTH)) w2r_sync (.clk(clk_rd), .reset_n(reset_n), .i_wr_ptr(wr_ptr_bin), .o_wr_ptr(wr_ptr_grey));

//Synchronize read clock domain data into write clock domain
sync_r2w #(.ADDR_WIDTH(ADDR_WIDTH)) r2w_sync (.clk(clk_wr), .reset_n(reset_n), .i_rd_ptr(rd_ptr_bin), .o_rd_ptr(rd_ptr_grey));

/* Output signals */
assign full = fifo_full;
assign empty = fifo_empty;

endmodule
