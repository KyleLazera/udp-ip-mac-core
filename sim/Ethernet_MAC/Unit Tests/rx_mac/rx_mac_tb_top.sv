`timescale 1ns / 1ps
`include "rx_mac_gen.sv"

module rx_mac_tb_top;

    localparam DATA_WIDTH = 8;
    
    logic clk, reset_n;
    logic [DATA_WIDTH-1:0] m_rx_axis_tdata;             
    logic m_rx_axis_tvalid;                             
    logic m_rx_axis_tuser;                              
    logic m_rx_axis_tlast;                             
    logic s_rx_axis_trdy;                               
    logic [DATA_WIDTH-1:0] rgmii_mac_rx_data;           
    logic rgmii_mac_rx_dv;                              
    logic rgmii_mac_rx_er;                              
    logic mii_select;                                       
    
    // Variables                                                     //Holds clock period ofor teh rgmii rx clk
    int clk_prd;
    
    // Design Under Test Instantiation 
    rx_mac #(.DATA_WIDTH(DATA_WIDTH)) DUT (.*);  
    
    rx_packet in_data;   
    
    //Clocks
    always #(clk_prd/2) clk = ~clk;
    
    initial begin
        //Init Signals
        clk = 1'b0;
    
        //Initializew class
        in_data = new();
        clk_prd = in_data.clk_prd;
        
        //Reset
        reset_n = 1'b0;
        #50 reset_n = 1'b1;
        #10;
           
        /*foreach(in_data.pckt[i]) begin           
            rgmii_mac_rx_data <= in_data.pckt[i].data;
            rgmii_mac_rx_dv <= in_data.pckt[i].dv;
            rgmii_mac_rx_er <= in_data.pckt[i].er;
            @(posedge clk);           
        end     */               
                    
        //#1000;
        $finish;
    end
    
    
endmodule
