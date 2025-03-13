`timescale 1ns/1ps

////////////////////////////////////////////////////////////////////////
// This module is used to synchronize an asynchronous and synchronous reset
// signal. This module is used to synchronize a reset signal to be passed
// into an asynchronous reset.
// This module asserts the resets asynchronously - avoiding the issue of 
// deassertion missing the reset recovery time and de-asserts the reset 
// asynchronously - avoiding the possibility of missing the signal.
////////////////////////////////////////////////////////////////////////

module reset_sync #(
    parameter ACTIVE_LOW = 1 //Indicates whether the reset signal is active high or active low    
)
(
    input wire i_clk,
    input wire i_reset,
    output wire o_rst_sync
);

(* keep="true" *)
reg [1:0] resest_sync_reg;

//////////////////////////////////////////////////////////////////////////////
// The reset is asserted asynchronously and does not need to be aligned with
// the i_clk. It is de-asserted synchrnously and therefore is passed through
// a double flop synchronizer.
//////////////////////////////////////////////////////////////////////////////

generate
    if(ACTIVE_LOW == 1) begin
        always @(posedge i_clk or negedge i_reset) begin
            if(i_reset) begin
                resest_sync_reg[1] <= 1'b0;
                resest_sync_reg[0] <= 1'b0; 
            end else begin
                resest_sync_reg[1] <= resest_sync_reg[0];
                resest_sync_reg[0] <= 1'b1;
            end
        end
    end else begin
        always @(posedge i_clk or posedge i_reset) begin
            if(i_reset) begin
                resest_sync_reg[1] <= 1'b1;
                resest_sync_reg[0] <= 1'b1; 
            end else begin
                resest_sync_reg[1] <= resest_sync_reg[0];
                resest_sync_reg[0] <= 1'b0;
            end
        end
    end
endgenerate

assign o_rst_sync = resest_sync_reg[1];

endmodule