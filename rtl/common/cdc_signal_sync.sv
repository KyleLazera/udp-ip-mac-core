`timescale 1ns/1ps

module cdc_signal_sync 
#(
    parameter PIPELINE = 0,            // Allows user to specify an extra pipeline stage that can be used for pulse detection
    parameter WIDTH = 1,               // Determines the width of the data being passed accross the clock domain
    parameter BOTH_EDGES = 0           // Determines whether the pulse detects both rising and falling edges or only rising edge
)
(
    input wire i_dst_clk,
    input wire [WIDTH-1:0] i_signal,
    /* Synchronized signals */
    output wire [WIDTH-1:0] o_signal_sync,
    output reg [WIDTH-1:0] o_pulse_sync
);

//Synthesis directive indicative asynch regs and to keep/not optimize out
(* async_reg="true", keep="true" *) reg [1:0][WIDTH-1:0] cdc_signal_sync_reg = '{2{WIDTH'(0)}};

genvar i;

generate
    //Paramterized double flop synchronizer logic
    for(i = 0; i < WIDTH; i = i + 1) begin
        always@(posedge i_dst_clk) begin
            cdc_signal_sync_reg[1][i] <= cdc_signal_sync_reg[0][i];
            cdc_signal_sync_reg[0][i] <= i_signal[i];
        end
    end
endgenerate

// Pulse Generation Logic 
generate
    genvar j;
    
    if(PIPELINE == 1) begin
           
        reg [WIDTH-1:0] sync_signal_reg = {WIDTH{1'b0}};

        for(j = 0; j < WIDTH; j = j + 1) begin
            //Pass the output of 2nd sync FF to pipeline FF & output the pulse
            always @(posedge i_dst_clk) begin
                sync_signal_reg[j] <= cdc_signal_sync_reg[1][j];
                o_pulse_sync[j] <= (BOTH_EDGES) ? sync_signal_reg[j] ^ cdc_signal_sync_reg[1][j] : !sync_signal_reg[j] & cdc_signal_sync_reg[1][j];
            end
        end

        assign o_signal_sync = sync_signal_reg;

    end else begin
        for(j = 0; j < WIDTH; j = j + 1) begin
            always @(posedge i_dst_clk)
                o_pulse_sync[j] <= 1'b0;
        end

        assign o_signal_sync = cdc_signal_sync_reg[1];
    end
endgenerate


endmodule