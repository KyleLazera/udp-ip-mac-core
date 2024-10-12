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

logic [CRC_WIDTH-1:0] crc_lut [TABLE_DEPTH-1:0];            //LUT Decleration

//Set clk period (8ns for 125 MHz)
always #4 clk = ~clk;

//LUT Init
/*initial begin
    $readmemb("C:/Users/klaze/Xilinx_FGPA_Projects/FPGA_Based_Network_Stack/Software/CRC_LUT.txt", crc_lut);
end

*
 * @Brief Reference Model that implements the CRC32 algorithm for each byte passed into it
 * @param i_byte Takes in a byte to pass into the model
 * @retval Returns the CRC32 current CRC value to append to the data message
*
function automatic [31:0] crc32_reference_model;
    input [7:0] i_byte;
    input [31:0] crc_state;
    input last;
    
    * Intermediary Signals *
    reg [31:0] crc_state_rev;
    reg [7:0] i_byte_rev, table_index;
    integer i;
    
    * Reverse the bit order of the byte in question *
    i_byte_rev = 0;
    for(int j = 0; j < 8; j++)
       i_byte_rev[j] = i_byte[(DATA_WIDTH-1)-j];
       
    * XOR this value with the MSB of the current CRC State *
    table_index = i_byte_rev ^ crc_state[31:24];
    
    * Index into the LUT and XOR the output with the shifted CRC *
    crc_state = {crc_state[24:0], 8'h0} ^ crc_lut[table_index];
    
    if(last == 1) begin
        * Reverse & Invert the final CRC State after all bytes have been iterated through *
        crc_state_rev = 32'h0;
        for(int k = 0; k < 32; k++) 
            crc_state_rev[k] = crc_state[(CRC_WIDTH-1)-k];
            
        crc_state = ~crc_state_rev;            
    end
    
    * Output The new CRC32 State *
    crc32_reference_model = crc_state;
    
endfunction : crc32_reference_model

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
    
endtask : fifo_sim

* RGMII Interface Task *
task rgmii_sim();
    //Simulate a 1000Mbps for now since this is teh targeted throughput. This
    //means driving the tx rdy signal at all times and pulling mii select low
    mii_select = 1'b0;
    rgmii_mac_tx_rdy = 1'b1;
endtask : rgmii_sim*/

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
