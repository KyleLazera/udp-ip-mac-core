
`include "rgmii_rx_bfm.sv"
`include "rgmii_tx_bfm.sv"
`include "eth_mac.sv"

/* 
 * This is a very simple testbench that simply drives some data into the top project design 
 * and mkaes sure the output matches. This tests mainly the feedback logic in the top level design.
 */

module top_hdl_tb;

//instantiate instance of mac to imsulate data
eth_mac mac_sim;
event write_complete;

bit clk_100;
bit reset_n;

class rgmii;

    bit [7:0] rx_data[$];
    bit [7:0] data_queue[$];
    bit bad_pckt;

    //Generate data to send
    function void generate_data();
        int pckt_size = $urandom_range(20, 1500);
        //Clear the queue
        data_queue.delete();

        for(int i = 0; i < pckt_size; i++)
            data_queue.push_back($urandom_range(0, 255));

        mac_sim.encapsulate_data(data_queue);
    endfunction : generate_data

    function void data_check();
        //Assert and check that the data sizes match
        assert(rx_data.size() == data_queue.size()) 
        else begin
            $display("RX Data size %0d != TX Data size %0d", rx_data.size(), data_queue.size());
            $stop;
        end 

        //Ensure all teh data wihtin the Packets match
        foreach(rx_data[i]) begin
           assert(rx_data[i] == data_queue[i]) //$display("Rx Data %0h == TX Data %0h MATCH", rx_data[i], data_queue[i]);
               else $display("RX Data %0h != TX Data %0h MISMATCH", rx_data[i], data_queue[i]);
        end

    endfunction : data_check

endclass : rgmii

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

rgmii rgmii_sim;

task read_rgmii_data(rgmii rx_data, bit [1:0] link_speed);
    bit [7:0] queue[$];
    rx_data.rx_data.delete();
    
    @(posedge rgmii_tx.rgmii_phy_txctl);
    while (rgmii_tx.rgmii_phy_txctl) begin
        logic [3:0] lower_nibble, upper_nibble;
        logic [7:0] sampled_byte;
        
        @(posedge rgmii_tx.rgmii_phy_txc);
        if(rgmii_tx.rgmii_phy_txctl) begin
            lower_nibble = rgmii_tx.rgmii_phy_txd;
            if(link_speed == 2'b00)
                @(negedge rgmii_tx.rgmii_phy_txc);  
            else
                @(posedge rgmii_tx.rgmii_phy_txc);
            upper_nibble = rgmii_tx.rgmii_phy_txd;
            sampled_byte = {upper_nibble, lower_nibble};            
            rx_data.rx_data.push_back(sampled_byte);
        end
    end
    
endtask : read_rgmii_data

initial begin    
    //Create instance of new class
    mac_sim = new();
    rgmii_sim = new();

    rgmii_rx.rgmii_reset();

    // Generate clock for rgmii
    fork
        rgmii_rx.generate_clock(2'b01);
    join_none  

    // Reset Logic
    reset_n = 1'b0;
    repeat(10)
    #1000;
    reset_n = 1'b1;    

    //generate rx data
    rgmii_sim.generate_data();  
     
    #10000;

     //Transmit and read teh data on the RGMII pins
     fork
        begin
            repeat(10) begin
                rgmii_rx.rgmii_drive_data(rgmii_sim.data_queue, 2'b01, 1'b0, rgmii_sim.bad_pckt);
                @write_complete;
            end
        end
        begin
            while(1) begin
                read_rgmii_data(rgmii_sim, 2'b01);  
                rgmii_sim.data_check();
                ->write_complete;
            end
        end      
     join_any 
    
    
    $finish;

end

endmodule