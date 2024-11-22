`timescale 1ns / 1ps

//UVM Includes
`include "uvm_macros.svh"  // Import UVM macros
import uvm_pkg::*;         // Import all UVM classes

`include "rx_mac_test.sv"
`include "rx_mac_if.sv"

module rx_mac_tb_top;
    logic clk;                                                              
    
    //Init Interface
    always #8 clk = ~clk;       //Todo: this needs to be variable to smiulate different clock periods (different tests)
    rx_mac_if _if(clk);
    
    // Design Under Test Instantiation - Connect with the interface 
    rx_mac #(.DATA_WIDTH(8)) DUT (.clk(clk), .reset_n(_if.reset_n), .m_rx_axis_tdata(_if.m_rx_axis_tdata),
                                          .m_rx_axis_tvalid(_if.m_rx_axis_tvalid), .m_rx_axis_tuser(_if.m_rx_axis_tuser),
                                          .m_rx_axis_tlast(_if.m_rx_axis_tlast), .s_rx_axis_trdy(_if.s_rx_axis_trdy), 
                                          .rgmii_mac_rx_data(_if.rgmii_mac_rx_data), .rgmii_mac_rx_dv(_if.rgmii_mac_rx_dv), 
                                          .rgmii_mac_rx_er(_if.rgmii_mac_rx_er));  
    
    //Bind the system verilog assertions module to the DUT
    bind rx_mac rx_mac_sva assertions_inst (
        .clk(clk),
        .reset_n(reset_n),
        .m_rx_axis_tdata(m_rx_axis_tdata),
        .m_rx_axis_tvalid(m_rx_axis_tvalid),
        .m_rx_axis_tuser(m_rx_axis_tuser),
        .m_rx_axis_tlast(m_rx_axis_tlast),
        .s_rx_axis_trdy(s_rx_axis_trdy),
        .rgmii_mac_rx_data(rgmii_mac_rx_data),
        .rgmii_mac_rx_dv(rgmii_mac_rx_dv),
        .rgmii_mac_rx_er(rgmii_mac_rx_er)
    );  
    
    initial begin
        //Init Signals
        clk = 1'b0;
    
        //Register the interface with the config db
        uvm_config_db#(virtual rx_mac_if)::set(null, "uvm_test_top", "rx_mac_vif", _if);
        //Run the default test instance
        run_test("rx_mac_test");
    end
       
endmodule
