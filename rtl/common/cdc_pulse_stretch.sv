`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////////////////
// This module is used to pass an input signal or pulse from the src domain to the dst domain 
// using feedback to ensure the pulse or signal was not missed. The module first identifies 
// either a rising or falling edge of the input signal. Once this is detected, the pulse is
// stretched. This stretched pulse will remain high until the dst domain has acknlowedged 
// that is has recieved teh pulse/signal. This is achieved by passing the the stretched pulse 
// to the dst domain, and then immediatelky passing it back to the src domain. Once the pulse 
// arrives back at the source domain, we know the pulse/signal was succesfully synchronzied and
// the stretched pulse can be lowered.
//////////////////////////////////////////////////////////////////////////////////////////////


module cdc_pulse_stretch
#(
    parameter RISING_EDGE = 1             //Determines which edge is detected on the i_pulse
                                          // 1 = rising edge detection
                                          // 2 = falling edge detection
)(
    input wire i_src_clk,                 //Source Clock Domain
    input wire i_dst_clk,                 //Destination Clock Domain

    input wire i_signal,                  //Input signal to cross domain
    output reg o_pulse,                   // Pulse (edge detection) of input signal in destination domain
    output reg o_signal                   // Synchronized output signal
);

/* 
 * Retime the pulse - This is needed specifically for when the link speed is 10/100mbps.
 * In this scenario, the pulses will be much larger than dst domain clock pulse, therefore, rather
 * than passing the entire pulse through, we only detect the rising edge of the pulse.
 */

reg pulse_rt;
wire pulse_edge;

always @(posedge i_src_clk) begin
    pulse_rt <= i_signal;
end

generate 
    if(RISING_EDGE)
        assign pulse_edge = !pulse_rt & i_signal;
    else
        assign pulse_edge = pulse_rt & !i_signal;
endgenerate


reg pulse_stretch = 1'b0;

always @(posedge i_src_clk) begin
    //When an edge is detected, stretch the pulse
    if(pulse_edge)
        pulse_stretch <= 1'b1;
    //Once the feedback pulse has been passed into the original source domain,
    // lower the stretched pulse
    else if(feedback_pulse)
        pulse_stretch <= 1'b0;
end

// Cross the stretched pulse into the destination domain

wire pulse_stretched_sync;
reg pulse_stretched_pipeline_1;

cdc_signal_sync #(.PIPELINE(1)) stretched_pulse_sync(
    .i_dst_clk(i_dst_clk),
    .i_signal(pulse_stretch),
    .o_signal_sync(pulse_stretched_sync),
    .o_pulse_sync(o_pulse)
);

//Cross the stretched pulse back into the source domain as a feedback signal

wire feedback_pulse;

cdc_signal_sync #(.PIPELINE(1)) feedback_sync(
    .i_dst_clk(i_src_clk),
    .i_signal(pulse_stretched_sync),
    .o_signal_sync(/*Not Needed*/),
    .o_pulse_sync(feedback_pulse)
);

// Ouput Signal
assign o_signal = pulse_stretched_sync;


endmodule