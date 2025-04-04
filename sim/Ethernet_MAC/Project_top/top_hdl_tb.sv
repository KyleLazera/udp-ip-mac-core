
`include "rgmii_rx_bfm.sv"
`include "eth_mac.sv"

/* 
 * This is a very simple testbench that simply drives some data into the top project design 
 * and mkaes sure the output is correct.
 */

module top_hdl_tb;

//instantiate instance of mac to imsulate data
eth_mac mac_sim;

logic clk_100;
logic reset_n;

bit [7:0] data_queue[$];
bit bad_pckt;

//Clock Generation
initial begin
    clk_100 = 1'b0;    
end

always #5 clk_100 = ~clk_100; //100MHz

//Interface Instantiation
rgmii_rx_bfm rgmii_rx();

function generate_data();
    int pckt_size = $urandom_range(20, 1500);
    //Clear the queue
    data_queue.delete();

    for(int i = 0; i < pckt_size; i++)
        data_queue.push_back($urandom_range(0, 255));

    mac_sim.encapsulate_data(data_queue);
endfunction : generate_data

/* DUT Instantiation */
ethernet_mac_project_top dut(
    .i_clk(clk_100),
    .i_reset_n(reset_n),
    .rgmii_phy_rxc(rgmii_rx.rgmii_phy_rxc),                                 
    .rgmii_phy_rxd(rgmii_rx.rgmii_phy_rxd),            
    .rgmii_phy_rxctl(rgmii_rx.rgmii_phy_rxctl),                                 
    .rgmii_phy_txc(rgmii_phy_txc),                               
    .rgmii_phy_txd(rgmii_phy_txd),         
    .rgmii_phy_txctl(rgmii_phy_txctl)    
);

initial begin
    //Create instance of new class
    mac_sim = new();

    reset_n = 1'b0;
    repeat(10)
        @(posedge clk_100);

    reset_n = 1'b1;    

    //generate rx data
    generate_data();

    //todo: test with diff modes here
    fork
        rgmii_rx.generate_clock(2'b00);
    join_none
    
    rgmii_rx.rgmii_drive_data(data_queue, 2'b00, 1'b0, bad_pckt);

    wait(rgmii_phy_txctl);
    wait(!rgmii_phy_txctl);

    $finish;

end

endmodule