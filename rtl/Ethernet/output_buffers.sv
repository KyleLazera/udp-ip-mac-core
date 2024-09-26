`timescale 1ns / 1ps


module output_buffers
#(parameter DATA_WIDTH = 5)
(
    input wire clk,                             //Input clock to dirve the ODDR Flip Flop (Must have 90 degree phase shift to align data)
    input wire [DATA_WIDTH-1:0] d_in_1,         //Data line 1
    input wire [DATA_WIDTH-1:0] d_in_2,         //Data line 2
    output wire [DATA_WIDTH-1:0] d_out          //Ouput data signal
);

generate 

genvar i;

for(i = 0; i < DATA_WIDTH; i++) begin
    ODDR #(
       .DDR_CLK_EDGE("SAME_EDGE"),      // SAME_EDGE allows inputs to be clocked on posedge of clock
       .INIT(1'b0),                     // Initial value of Q: 1'b0 or 1'b1
       .SRTYPE("SYNC")                  // Set/Reset type: "SYNC" or "ASYNC"
    ) ODDR_inst (
       .Q(d_out[i]),                    // 1-bit DDR output
       .C(clk),                         // 1-bit clock input
       .CE(1'b1),                       // 1-bit clock enable input
       .D1(d_in_1[i]),                  // 1-bit data input (positive edge)
       .D2(d_in_2[i]),                  // 1-bit data input (negative edge)
       .R(1'b0),                        // 1-bit reset
       .S(1'b0)                         // 1-bit set
    );
end


endgenerate

endmodule
