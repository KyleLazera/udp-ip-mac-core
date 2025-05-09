
`include "rgmii_rx_bfm.sv"
`include "rgmii_tx_bfm.sv"
`include "network_stack.sv"

/* 
 * This is a very simple testbench that simply drives some data into the top project design 
 * and mkaes sure the output matches. This tests mainly the feedback logic in the top level design.
 */

import network_stack::*;

module top_hdl_tb;

//Instantiate class and struct instances
ip_stack ip_sim;
pckt_t tx_pckt, rx_pckt;

// Clock and reset signals
bit clk_100;
bit reset_n;

bit bad_pckt;

//Clock Generation
initial begin
    clk_100 = 1'b0;    
end

always #5 clk_100 = ~clk_100; //100MHz

//Interface Instantiation
rgmii_rx_bfm rgmii_rx();
rgmii_tx_bfm rgmii_tx();

/* DUT Instantiation */
ethernet_mac_project_top dut(
    .i_clk(clk_100),
    .i_reset_n(reset_n),
    .rgmii_phy_rxc(rgmii_rx.rgmii_phy_rxc),                                 
    .rgmii_phy_rxd(rgmii_rx.rgmii_phy_rxd),            
    .rgmii_phy_rxctl(rgmii_rx.rgmii_phy_rxctl),                                 
    .rgmii_phy_txc(rgmii_tx.rgmii_phy_txc),                               
    .rgmii_phy_txd(rgmii_tx.rgmii_phy_txd),         
    .rgmii_phy_txctl(rgmii_tx.rgmii_phy_txctl)    
);

task read_rgmii_data(ref pckt_t rx_pckt);
    bit [7:0] queue[$];
    rx_pckt.payload.delete();
    
    @(posedge rgmii_tx.rgmii_phy_txctl);
    while (rgmii_tx.rgmii_phy_txctl) begin
        logic [3:0] lower_nibble, upper_nibble;
        logic [7:0] sampled_byte;
        
        @(posedge rgmii_tx.rgmii_phy_txc);
        if(rgmii_tx.rgmii_phy_txctl) begin
            lower_nibble = rgmii_tx.rgmii_phy_txd;
            @(negedge rgmii_tx.rgmii_phy_txc);  
            upper_nibble = rgmii_tx.rgmii_phy_txd;
            sampled_byte = {upper_nibble, lower_nibble};            
            rx_pckt.payload.push_back(sampled_byte);
        end
    end
    
endtask : read_rgmii_data

initial begin    
    //Create instance of new class
    ip_sim = new();

    rgmii_rx.rgmii_reset();

    // Generate clock for rgmii
    fork
        rgmii_rx.generate_clock(2'b00);
    join_none  

    // Reset Logic
    reset_n = 1'b0;
    repeat(10)
    #1000;
    reset_n = 1'b1;     
     
    #10000;

     //Transmit and read teh data on the RGMII pins
     fork
        begin
            repeat(100) begin
                // Generate and transmit a packet of data to the rx end of the rgmii inputs
                ip_sim.generate_packet(tx_pckt); 
                rgmii_rx.rgmii_drive_data(tx_pckt.payload, 2'b00, 1'b0, bad_pckt);
                @(ip_sim.check_complete);
            end
        end
        begin
            forever begin
                read_rgmii_data(rx_pckt);  
                ip_sim.check_data(tx_pckt, rx_pckt);
            end
        end      
     join_any

     
    #1000;
    
    $finish;

end

endmodule