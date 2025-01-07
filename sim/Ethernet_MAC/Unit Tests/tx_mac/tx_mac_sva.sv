`timescale 1ns / 1ps


module tx_mac_sva
#(parameter DATA_WIDTH = 8)
(
    input clk, 
    input reset_n,
    input [DATA_WIDTH-1:0] s_tx_axis_tdata,            
    input s_tx_axis_tvalid,                            
    input s_tx_axis_tlast,                             
    input s_tx_axis_tkeep,                             
    input s_tx_axis_tuser,                             
    input s_tx_axis_trdy,                             
    input rgmii_mac_tx_rdy,                            
    input [DATA_WIDTH-1:0] rgmii_mac_tx_data,         
    input rgmii_mac_tx_dv,                            
    input rgmii_mac_tx_er,                            
    input mii_select                                   
);

//s_tx_axis_rdy should be low after the rgmii_rdy signal is low
property tx_mac_rdy;
@(posedge clk) disable iff(!reset_n)
    $fell(rgmii_mac_tx_rdy) |=> !s_tx_axis_trdy;
endproperty : tx_mac_rdy

//If teh rgmii_rdy signal goes low, the FIFO data should not change
property rgmii_not_rdy;
@(posedge clk) disable iff(!reset_n)
    $fell(rgmii_mac_tx_rdy) |=> (s_tx_axis_tdata == $past(s_tx_axis_tdata, 1));
endproperty : rgmii_not_rdy

//If RGMII is not ready, on the next clock edge data valid should go low
property tx_data_valid_and_rgmii_not_rdy;
@(posedge clk) disable iff(!reset_n)
    $fell(rgmii_mac_tx_rdy) |=> !rgmii_mac_tx_dv;
endproperty : tx_data_valid_and_rgmii_not_rdy

/* Properties for gbps tests*/

sequence preamble_gbps;
    (rgmii_mac_tx_data == 8'h55) [*7] ##1 (rgmii_mac_tx_data == 8'hD5);
endsequence : preamble_gbps

property preamble_start_gbps;
@(posedge clk) disable iff(!reset_n)
    ((!mii_select && $rose(s_tx_axis_tvalid) && ~s_tx_axis_trdy) |-> ##2 preamble_gbps);
endproperty : preamble_start_gbps


/* Properties for mbps tests */

sequence preamble_mbps;
    (rgmii_mac_tx_data == 8'h55) ##2 (rgmii_mac_tx_data == 8'h55) ##2
    (rgmii_mac_tx_data == 8'h55) ##2 (rgmii_mac_tx_data == 8'h55) ##2
    (rgmii_mac_tx_data == 8'h55) ##2 (rgmii_mac_tx_data == 8'h55) ##2
    (rgmii_mac_tx_data == 8'h55) ##2 (rgmii_mac_tx_data == 8'hD5);
endsequence : preamble_mbps

property preamble_start_mbps;
@(posedge clk) disable iff(!reset_n)
    ((mii_select && $rose(s_tx_axis_tvalid) && ~s_tx_axis_trdy) |-> ##2 preamble_mbps);
endproperty : preamble_start_mbps

property rgmii_data_left_shift;
@(posedge clk) disable iff(!reset_n)
    (mii_select && $rose(rgmii_mac_tx_dv) && rgmii_mac_tx_rdy) |=> (rgmii_mac_tx_data == ($past(rgmii_mac_tx_data, 1) >> 4));
endproperty : rgmii_data_left_shift

/* Concurrent Assertions */

assert property(tx_mac_rdy) else
    $fatal("Failed Assertion: s_tx_axis_trdy was not low after rgmii was not ready");
    
assert property(rgmii_not_rdy) else
    $fatal("Failed Assertion: FIFO data updated after rgmii was not ready");        

assert property(preamble_start_gbps) else
    $fatal("Failed the preamble gbps start assertion at time: %t", $time);
    
assert property(preamble_start_mbps) else
    $fatal("Failed the preamble mbps start assertion at time: %t", $time);
    
assert property(tx_data_valid_and_rgmii_not_rdy) else
    $fatal("Data Valid did not go low after rgmii not ready at time: %t", $time);
    
assert property(rgmii_data_left_shift) else
    $fatal("Failed to shift rgmii data at time: %t", $time);

endmodule
