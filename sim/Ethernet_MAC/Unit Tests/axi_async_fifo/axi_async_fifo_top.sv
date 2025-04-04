`timescale 1ns / 1ps

`include "axi_stream_rx_bfm.sv"
`include "axi_stream_tx_bfm.sv"
`include "axi_async_fifo_pkg.sv"
`include "axi_async_fifo_test.sv"

module axi_async_fifo_top;

localparam PERIOD_10_NS = 5;
localparam PERIOD_8_NS = 4;

/* Clocks and reset Signals */
logic clk_100;
logic clk_125;
logic m_resetn;
logic s_resetn;

/* Interfaces/BFM's */
axi_stream_tx_bfm #(.AXI_DATA_WIDTH(8)) axis_tx(.s_aclk(clk_125), .s_sresetn(s_resetn));
axi_stream_rx_bfm #(.AXI_DATA_WIDTH(8)) axis_rx(.m_aclk(clk_100), .m_sresetn(m_resetn));

import axi_async_fifo_pkg::*;
axi_async_fifo_test test;

//Initialize clocks
always #(PERIOD_10_NS) clk_100 = ~clk_100;
always #(PERIOD_8_NS) clk_125 = ~clk_125;

initial begin
    clk_100 = 1'b0;
    clk_125 = 1'b0;
end

//DUT Instantiation
axi_async_fifo #(
    .AXI_DATA_WIDTH(8),
    .PIPELINE_STAGES(2),
    .FIFO_ADDR_WIDTH(12)
) async_fifo (
    .m_aclk(clk_100),
    .m_sresetn(m_resetn),
    .m_axis_tdata(axis_rx.m_axis_tdata),
    .m_axis_tlast(axis_rx.m_axis_tlast),
    .m_axis_tvalid(axis_rx.m_axis_tvalid),
    .m_axis_trdy(axis_rx.m_axis_trdy),

    .s_aclk(clk_125),
    .s_sresetn(s_resetn),
    .s_axis_tdata(axis_tx.s_axis_tdata),
    .s_axis_tlast(axis_tx.s_axis_tlast),
    .s_axis_tvalid(axis_tx.s_axis_tvalid),
    .s_axis_tuser(axis_tx.s_axis_tuser),
    .s_axis_trdy(axis_tx.s_axis_trdy)    
);

initial begin
    m_resetn = 0;
    s_resetn = 0;
    axis_tx.s_axis_tdata = '0;
    axis_tx.s_axis_tlast = 0;
    axis_tx.s_axis_tvalid = 0; 
    axis_rx.m_axis_trdy = 0;
    axis_tx.s_axis_tuser = 0;

    repeat(10)
        @(posedge clk_100);

    m_resetn = 1;
    s_resetn = 1; 

    //Instantiate the test class
    test = new(axis_tx, axis_rx);

    test.test_sanity();
    test.write_read();

    #100;

    $finish;

end

endmodule