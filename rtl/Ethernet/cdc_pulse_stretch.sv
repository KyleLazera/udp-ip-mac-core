`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////////////////
// This module is used to cross a pulse from a faster clock domain (125MHz) into
// a slower clock domain (100MHz). Because the pulse is originally occuring in
// the 125MHz clock domain, there is a risk that it could be missed by the 
// recieveing clock domain (100MHz) if only a series of synchronizer FF's are used.
// To avoid this the pulse is stretched, and this newly stretched pulse is passed
// through the synchronizer FF's. 
// To lower the strecthed pulse, once a pulse has been generated in the destination domain,
// the original stretched pulse is then passed back into the source clock domain. Once
// the source clock domain identifies the stretched pulse being passed back, it triggers the 
// stretche dpulse to be lowered.
//
// Note: Because the stretched pulse has to be passed from the source domain and then
// back to the destination domain, pulses cannot occur within 6-7 clock cycles of one another
// or else they will be missed.
//////////////////////////////////////////////////////////////////////////////////////////////


module cdc_pulse_stretch
(
    input wire i_src_clk,                 //Source Clock Domain
    input wire i_dst_clk,                 //Destination Clock Domain

    input wire i_pulse,                   //Input pulse to cross domain
    output reg o_pulse                   //Equivelent output pulse
);

/* 
 * Retime the pulse - This is needed specifically for when the link speed is 10/100mbps.
 * In this scenario, the pulses will be much larger than dst domain clock pulse, therefore, rather
 * than passing the entire pulse through, we only detect the rising edge of the pulse.
 */

reg pulse_rt;
wire pulse_rising_edge;

always @(posedge i_src_clk) begin
    pulse_rt <= i_pulse;
end

assign pulse_rising_edge = !pulse_rt & i_pulse;

reg pulse_stretch = 1'b0;

always @(posedge i_src_clk) begin
    //When an edge is detected, stretch the pulse
    if(pulse_rising_edge)
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


endmodule