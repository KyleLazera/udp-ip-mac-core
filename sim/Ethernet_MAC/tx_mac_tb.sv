`timescale 1ns / 1ps

/*
 * Currently doing manual testing by just driving stimulus to the module and monitoring outputs.
 * This is begin used to develop the module progressivley, rather than just developing it at once
 * and then testing and debugging the entire module.
 * This verification implementation will be improved upon to cover more functionality of teh device.
*/

module tx_mac_tb;

localparam DATA_WIDTH = 8;

/* Signals */
logic clk, reset_n;
logic [DATA_WIDTH-1:0] s_tx_axis_tdata;
logic s_tx_axis_tvalid;                
logic s_tx_axis_tlast;                     
logic s_tx_axis_tkeep;          //Currently Not being used            
logic s_tx_axis_tuser;          //Currently Not being used            
logic s_tx_axis_trdy;                  
logic rgmii_mac_tx_rdy;                
logic [DATA_WIDTH-1:0] rgmii_mac_tx_data;       
logic rgmii_mac_tx_dv;                          
logic rgmii_mac_tx_er;                          
logic mii_select;                                

/* Module Instantiation */
tx_mac#(.DATA_WIDTH(DATA_WIDTH)) DUT(.*);

//Set clk period (8ns for 125 MHz)
always #4 clk = ~clk;

/* Function that simulates the FIFO interacting via AXI Stream with the TXMAC */
task fifo_sim();
    int packet_ctr = 0;
    //Assume the FIFO always has data in it to send
    //s_tx_axis_tvalid = 1'b1;
    
    //While TxMAC raises trdy flag & we have not transmitted 100 packets, generate and send
    //random bytes of data to the TxMAC
    while(s_tx_axis_trdy && (packet_ctr < 100)) begin
        @(posedge clk);
        if(packet_ctr == 99)
            s_tx_axis_tlast = 1'b1;
        
        s_tx_axis_tdata = $urandom_range(0, 255);
        packet_ctr++;
    end
    
    s_tx_axis_tlast = 1'b0;
    
endtask : fifo_sim

/* RGMII Interface Task */
task rgmii_sim();
    //Simulate a 1000Mbps for now since this is teh targetted throughput. This
    //means driving the tx rdy signal at all times and pulling mii select low
    mii_select = 1'b0;
    rgmii_mac_tx_rdy = 1'b1;
endtask : rgmii_sim

initial begin
    //Init Reset and clock vals
    clk = 0;
    reset_n = 0;
    #50;
    reset_n = 1;
    
    //Call he RGMII interface sim
    rgmii_sim();
    s_tx_axis_tvalid = 1'b1;
    
    #100;
    
    //Simulate FIFO functionality to transmit data
    fifo_sim();
    
    $finish;
      
end

endmodule
