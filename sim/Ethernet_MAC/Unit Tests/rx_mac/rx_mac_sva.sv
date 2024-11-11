`timescale 1ns / 1ps

/*
 * This file contains a series of assertions that are used to verify the funcitonality of the rx mac.
 * Below are a series of rules that are used to guide the assertions and check the DUT functionality:
 *  1)
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
    input logic rgmii_mac_rx_er,                              
    input logic mii_select        
);

/* Sequences */
sequence ethernet_header;
    ((rgmii_mac_rx_data == 8'h55) [*7] ##1 (rgmii_mac_rx_data == 8'hD5));
endsequence : ethernet_header

/* Properties */

/* This checks for when the rgmii_dv signal goes high, there is an ethernet header following */
property header_check;
@(posedge clk) disable iff(~reset_n)
    $rose(rgmii_mac_rx_dv) |-> ethernet_header;
endproperty : header_check

/* This property checks to see if the data on the axis_data line was present on the rgmii_data line 6 clock cycles prior*/
property rgmii_to_fifo;
@(posedge clk) disable iff(~reset_n)
    m_rx_axis_tvalid |-> (m_rx_axis_tdata == $past(rgmii_mac_rx_data, 6));
endproperty : rgmii_to_fifo

/* Once the last byte has been identified, the valid signal for the AXI signal should go low */
property last_byte;
@(posedge clk) disable iff(~reset_n)
    $rose(m_rx_axis_tlast) |=> $fell(m_rx_axis_tvalid);        
endproperty : last_byte

/* Concurrent Assertions */

assert property(rgmii_to_fifo) else $display("Failed Assertion");

assert property(header_check) else $display("Header assertion Failed");

assert property(last_byte) else $display("Last Byte Assertion Failed");

endmodule
