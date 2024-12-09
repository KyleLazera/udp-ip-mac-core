`include "async_fifo_pkg.svh"

/* Virtual interface for writing to the FIFO */

interface wr_if(input clk_wr, input reset_n);
    bit [FIFO_DATA_WIDTH - 1:0] data_in;
    bit wr_en;
    bit full;
endinterface : wr_if

/* Virtual Interface for Reading from the FIFO */

interface rd_if(input clk_rd, input reset_n);
    bit [FIFO_DATA_WIDTH - 1:0] data_out;
    bit rd_en;
    bit empty;
endinterface : rd_if
