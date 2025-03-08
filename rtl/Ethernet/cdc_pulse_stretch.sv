`timescale 1ns / 1ps

module cdc_pulse_stretch
(
    input wire i_src_clk,                 //Source Clock Domain
    input wire i_dst_clk,                 //Destination Clock Domain

    input wire i_pulse,                   //Input pulse to cross domain
    output reg o_pulse                   //Equivelent output pulse
);

/* Retime the pulse - This is needed for 10/100 mbps link speeds where the pulse
will be very long. Used to capyture only the rising edge of the pulse */
reg pulse_rt;
wire pulse_rising_edge;

always @(posedge i_src_clk) begin
    pulse_rt <= i_pulse;
end

assign pulse_rising_edge = !pulse_rt & i_pulse;

reg i_pulse_stretch = 1'b0;

always @(posedge i_src_clk) begin
    if(pulse_rising_edge)
        i_pulse_stretch <= 1'b1;
    //Falling edge detection of the feedback signal
    else if(feedback_pulse_stretched[1] & !feedback_pulse_stretched[2])
        i_pulse_stretch <= 1'b0;
end

/* Synchonrize the stretched pulse with the destination clock domain  & generate a pulse*/
reg [2:0] pulse_stretched_resync = 3'b0;
wire pulse_stretched;

always @(posedge i_dst_clk) begin
    pulse_stretched_resync <= {pulse_stretched_resync[1:0], i_pulse_stretch};
    o_pulse <= !pulse_stretched_resync[2] & pulse_stretched_resync[1];
end

assign pulse_stretched = pulse_stretched_resync[2];

/* Re-synchronize the stretched pulse back into the source domain for feedback */
reg [2:0] feedback_pulse_stretched = 3'b0;

always @(posedge i_src_clk) begin
    feedback_pulse_stretched <= {feedback_pulse_stretched[1:0], pulse_stretched};
end

endmodule