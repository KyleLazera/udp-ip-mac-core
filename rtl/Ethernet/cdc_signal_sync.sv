`timescale 1ns/1ps

module cdc_signal_sync 
#(
    parameter PIPELINE = 0            // Allows user to specify an extra pipeline stage that can be used for pulse detection
)
(
    input wire i_dst_clk,
    input wire i_signal,
    /* Synchronized signals */
    output wire o_signal_sync,
    output reg o_pulse_sync
);

//Synthesis directive indicative asynch regs and to keep/not optimize out
(* async_reg="true", keep="true" *) reg [1:0] cdc_signal_sync_reg = 2'b0;

//Double flop synchronizer logic 
always @(posedge i_dst_clk) begin
    cdc_signal_sync_reg[1] <= cdc_signal_sync_reg[0];
    cdc_signal_sync_reg[0] <= i_signal;
end

generate
    if(PIPELINE == 1) begin
        reg sync_signal_reg = 1'b0;

        //Pass the output of 2nd sync FF to pipeline FF & output the pulse 
        always @(posedge i_dst_clk) begin
            sync_signal_reg <= cdc_signal_sync_reg[1];
            o_pulse_sync <= !sync_signal_reg & cdc_signal_sync_reg[1];
        end

        assign o_signal_sync = sync_signal_reg;

    end else begin
        always @(posedge i_dst_clk)
            o_pulse_sync <= 1'b0;

        assign o_signal_sync = cdc_signal_sync_reg[1];

    end
endgenerate

endmodule