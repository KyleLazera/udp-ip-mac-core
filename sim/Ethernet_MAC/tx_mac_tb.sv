`timescale 1ns / 1ps

`include "tx_mac_test.sv"

module tx_mac_tb;

localparam DATA_WIDTH = 8;
localparam CRC_WIDTH = 32;
localparam TABLE_DEPTH = (2**DATA_WIDTH);

/* Signals */
logic clk, reset_n;

/* Initialize the interface */
tx_mac_if vif(.clk(clk), .reset_n(reset_n));                        
                      
/* Module Instantiation & connect with the interface*/
tx_mac#(.DATA_WIDTH(DATA_WIDTH)) DUT(.clk(clk), .reset_n(reset_n), .s_tx_axis_tdata(vif.s_tx_axis_tdata), .s_tx_axis_tvalid(vif.s_tx_axis_tvalid),
                                    .s_tx_axis_tlast(vif.s_tx_axis_tlast), .s_tx_axis_tkeep(vif.s_tx_axis_tkeep), .s_tx_axis_tuser(vif.s_tx_axis_tuser), 
                                    .s_tx_axis_trdy(vif.s_tx_axis_trdy),.rgmii_mac_tx_rdy(vif.rgmii_mac_tx_rdy), .rgmii_mac_tx_data(vif.rgmii_mac_tx_data),
                                     .rgmii_mac_tx_dv(vif.rgmii_mac_tx_dv), .rgmii_mac_tx_er(vif.rgmii_mac_tx_er), .mii_select(vif.mii_select));


//Set clk period (8ns for 125 MHz)
always #4 clk = ~clk;

/*

localparam PCKT_SIZE = 57;

* Function that simulates the FIFO interacting via AXI Stream with the TXMAC *
task fifo_sim();
    int packet_ctr = 0;
    bit last_pckt = 1'b0;
    reg[31:0] crc_state = 32'hFFFFFFFF;
  
    //While TxMAC raises trdy flag & we have not transmitted 100 packets, generate and send
    //random bytes of data to the TxMAC
    while(s_tx_axis_trdy && (packet_ctr < PCKT_SIZE)) begin
        @(posedge clk);
        //On the last packet raise the tlast flag
        if(packet_ctr == (PCKT_SIZE-1)) begin
            s_tx_axis_tlast = 1'b1;
            last_pckt = (PCKT_SIZE >= 60) ? 1'b1 : 1'b0;
        end
        
        //Generate random byte values
        s_tx_axis_tdata = $urandom_range(0, 255);
        crc_state = crc32_reference_model(s_tx_axis_tdata, crc_state, last_pckt);
        $display("0x%0h", s_tx_axis_tdata);
        packet_ctr++;
    end
    
    //If packet size is less than 60, add padding to the CRC reference model
    if(PCKT_SIZE < 60) begin
        for(int i = 0; i < (60 - PCKT_SIZE); i++) begin
            
            if(i == ((60 - PCKT_SIZE) - 1))
                last_pckt = 1'b1;
        
            crc_state = crc32_reference_model(8'h0, crc_state, last_pckt);
            $display("0x00");        
        end
    end
    
    @(posedge clk);
    s_tx_axis_tlast = 1'b0;
    
    $display("Calculated CRC32 based on reference model: %0h", crc_state);
    
endtask : fifo_sim*/


tx_mac_test test_demo;

initial begin
    //Init Reset and clock vals
    clk = 0;
    reset_n = 0;
    #50;
    reset_n = 1;
    #20;
    
    test_demo = new(vif);
    test_demo.main();
    
    #100;
    
    $finish;
      
end

endmodule
