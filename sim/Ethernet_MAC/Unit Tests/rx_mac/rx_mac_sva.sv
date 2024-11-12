`timescale 1ns / 1ps

/*
 * This file contains a series of assertions that are used to verify the funcitonality of the rx mac.
 * Below are a series of rules that are used to guide the assertions and check the DUT functionality:
 *  1) Data in the RGMII line should be present on the axis_data line 6 clock cycles later (assuming dv is high and er is low)
 *  2) After transmitting the last byte of data (rasising axis_tlast), the axis_valid should go low
 *  3) When axis_valid goes high, 7 clock cycles previously should be on rgmii_rx should be D5 (SFD), rgmii_dv should be high, 
        rgmii_er should be low, & axis_trdy should be high
 *  4) When the axis_tuser signal is raised, this indicates an error, and teh axis_tvalid signal should go low 1 clock cycle later        
*/

module rx_mac_sva
#(parameter DATA_WIDTH = 8)
(
    input logic clk, 
    input logic reset_n,
    input logic [DATA_WIDTH-1:0] m_rx_axis_tdata,             
    input logic m_rx_axis_tvalid,                             
    input logic m_rx_axis_tuser,                              
    input logic m_rx_axis_tlast,                             
    input logic s_rx_axis_trdy,                               
    input logic [DATA_WIDTH-1:0] rgmii_mac_rx_data,           
    input logic rgmii_mac_rx_dv,                              
    input logic rgmii_mac_rx_er                                   
);

/* Properties */

/* This check whether the header was correctly identified: SFD + data valid + no error + fifo Ready */
property hdr_check;
@(posedge clk) disable iff(~reset_n)
    $rose(m_rx_axis_tvalid) |-> (($past(rgmii_mac_rx_data, 7) == 8'hD5) && $past(rgmii_mac_rx_dv, 7) && 
    !$past(rgmii_mac_rx_er, 7) && $past(s_rx_axis_trdy, 7)); 
endproperty : hdr_check

/* This property checks to see if the data on the axis_data line was present on the rgmii_data line 6 clock cycles prior*/
property rgmii_to_fifo;
@(posedge clk) disable iff(~reset_n)
    m_rx_axis_tvalid |-> (m_rx_axis_tdata == $past(rgmii_mac_rx_data, 6));
endproperty : rgmii_to_fifo

/* Once the last byte has been identified, the valid signal for the AXI stream should go low */
property last_byte;
@(posedge clk) disable iff(~reset_n)
    $rose(m_rx_axis_tlast) |=> $fell(m_rx_axis_tvalid);        
endproperty : last_byte

/* If rgmii_dv falls, and 1 clock cycle later axis_last is raised, one clock cycle later axis_valid should go low */
property rgmii_dv_to_last_byte;
@(posedge clk) disable iff(~reset_n)
    ($fell(rgmii_mac_rx_dv) ##1 $rose(m_rx_axis_tlast)) |=> $fell(m_rx_axis_tvalid);    
endproperty : rgmii_dv_to_last_byte

/* If an error has occured (dv low, er high or crc not matching), tvalid should go low 1 clock cycle later */
property tuser_error;
@(posedge clk) disable iff(~reset_n)
    m_rx_axis_tuser |=> !m_rx_axis_tvalid;        
endproperty : tuser_error

/* Concurrent Assertions */

assert property(rgmii_to_fifo) else $display("Failed Assertion");

assert property(hdr_check) else $display("Header assertion Failed");

assert property(last_byte) else $display("Last Byte Assertion Failed");

assert property (rgmii_dv_to_last_byte) else $display("AXIS Data Validassertion failed");

assert property (tuser_error) else $display("Error Assertion Failed");

endmodule
