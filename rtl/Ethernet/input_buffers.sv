`timescale 1ns / 1ps

/*
 * This module is used to buffer the input signals into the RGMII interface from the PHY. The rx clk signal is used 
 * to drive the IDDR buffers and is also transmitted to the FPGA fabric to be used in the MAC module. The clock is passed
 * through an IOBUF and then passed to each IDDR, whereas the clock being passed into the FPGA logic is buffered by a BUFR.
*/

module input_buffers
#(parameter DATA_WIDTH = 5)
(
    input wire clk,                              //rx clk input from PHY (125MHz/25MHz/2.5MHz)
    input wire [DATA_WIDTH-1:0] d_in,            //RX input data + rx_ctrl        
    output wire o_clk,                           //output clock that interfaces with the MAC
    output wire [DATA_WIDTH-1:0] q1, q2          //IDDR output signals
);

wire i_clk;                         //Signal for the input clock from the PHY
wire clk_io;                        //Clock signal that is output from the BUFIO & used to drive other IO primitives
wire delayed_clk_io;                //This is only needed for simulation to ensure correct functionality of IDDR in testbench

assign i_clk = clk;

/** Input Clock Buffering **/

//This will buffer the input clk signal and transmit it to the IDDR registers
BUFIO BUFIO_inst (
 .I(i_clk),         // 1-bit input: Clock input 
 .O(clk_io)         // 1-bit output: Clock output (connect to I/O clock loads)
);

/*/Instantiate BUFR to connect input clock with with MAC 
BUFR #(
 .BUFR_DIVIDE("BYPASS"), 
 .SIM_DEVICE("7SERIES") 
)
BUFR_inst (
 .O(o_clk),         // 1-bit output: Clock output port
 .CE(1'b1),         // 1-bit input: Active high, clock enable (Divided modes only)
 .CLR(1'b0),        // 1-bit input: Active high, asynchronous clear (Divided modes only)
 .I(i_clk)          // 1-bit input: Clock buffer input driven by an IBUF, MMCM or local interconnect
);*/

// Drives the recieved clock into the rx MAC
BUFG
clk_bufg_inst (
    .I(i_clk),
    .O(o_clk)
);

assign #1 delayed_clk_io = clk_io; //Only for simulation

/** Input Data Buffering **/

generate 
    genvar i;

    //Create an IDDR for each of the input data signals from the PHY: rxd[3:0] & rxctl
    //Use the buffered input clock signal to drive the IDDR registers
    for(i = 0; i < DATA_WIDTH; i++) begin  
        // IDDR: Input Double Data Rate Input Register with Set, Reset
        IDDR #(
         .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"), 
         .INIT_Q1(1'b0),        // Initial value of Q1: 1'b0 or 1'b1
         .INIT_Q2(1'b0),        // Initial value of Q2: 1'b0 or 1'b1
         .SRTYPE("SYNC")        // Set/Reset type: "SYNC" or "ASYNC"
        ) IDDR_inst (
         .Q1(q1[i]),            // 1-bit output for positive edge of clock
         .Q2(q2[i]),            // 1-bit output for negative edge of clock
         .C(delayed_clk_io),    // 1-bit clock input
         .CE(1'b1),             // 1-bit clock enable input
         .D(d_in[i]),           // 1-bit DDR data input
         .R(1'b0),              // 1-bit reset
         .S(1'b0)               // 1-bit set
        );    
    end

endgenerate


endmodule
