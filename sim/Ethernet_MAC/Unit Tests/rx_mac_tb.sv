`timescale 1ns / 1ps

class crc32_checksum;
    /* Localparams */
    localparam DATA_WIDTH = 8;
    localparam CRC_WIDTH = 32;
    localparam TABLE_DEPTH = (2**DATA_WIDTH);
    
    /* Variables */
    logic [CRC_WIDTH-1:0] crc_lut [TABLE_DEPTH-1:0];    
    
    function new();
        //LUT Init
        $readmemb("C:/Users/klaze/Xilinx_FGPA_Projects/FPGA_Based_Network_Stack/Software/CRC_LUT.txt", crc_lut);
    endfunction : new
    
     /*
     * @Brief Reference Model that implements the CRC32 algorithm for each byte passed into it
     * @param i_byte Takes in a byte to pass into the model
     * @retval Returns the CRC32 current CRC value to append to the data message
    */
    function automatic [31:0] crc32_reference_model;
        input [7:0] i_byte_stream[];
        
        /* Intermediary Signals */
        reg [31:0] crc_state = 32'hFFFFFFFF;
        reg [31:0] crc_state_rev;
        reg [7:0] i_byte_rev, table_index;
        integer i;
        
        //Iterate through each byte in the stream
        foreach(i_byte_stream[i]) begin
             /* Reverse the bit order of the byte in question */
             i_byte_rev = 0;
             for(int j = 0; j < 8; j++)
                i_byte_rev[j] = i_byte_stream[i][(DATA_WIDTH-1)-j];
                
             /* XOR this value with the MSB of teh current CRC State */
             table_index = i_byte_rev ^ crc_state[31:24];
             
             /* Index into the LUT and XOR the output with the shifted CRC */
             crc_state = {crc_state[24:0], 8'h0} ^ crc_lut[table_index];
        end
        
        /* Reverse & Invert the final CRC State after all bytes have been iterated through */
        crc_state_rev = 32'h0;
        for(int k = 0; k < 32; k++) 
            crc_state_rev[k] = crc_state[(CRC_WIDTH-1)-k];
        
        crc32_reference_model = ~crc_state_rev;
        
    endfunction : crc32_reference_model     
    
endclass : crc32_checksum

class rgmii_pckt extends crc32_checksum;
    /* Localparams */
    localparam ETH_HDR = 8'h55;
    localparam ETH_SFD = 8'hD5; 
    
    /* Randomized Values for Tests */
    rand logic[7:0] payload [];                                        //Payload from packet
    rand logic rx_dv;                                                  // Data valid from RGMII
    rand logic rx_er;                                                  // Data error from RGMII
    rand int clk_prd;                                                  // clock period for rgmii rxc

    /* Non Randomized Values */
    logic [7:0] packet [];

    /* Constraints */
    //constraint payload_size {payload.size() inside {[46:1500]};}
    constraint payload_size {payload.size() inside {[10:15]};}
    constraint clk_const {clk_prd dist {400 := 30, 40 := 35, 8 := 35};}
    
    function new();
        this.randomize();
        $display("Values Randomized");
        generate_pckt(payload, packet);
        $display("Packet generated");
    endfunction : new
    
    //Task is used to generate a packet
    function void generate_pckt(ref logic [7:0] data_payload [], output logic [7:0] packet []);
        int payload_size;
        logic [31:0] crc;        
        logic [7:0] packet [];
        
        /* Caluclate CRC checksum */
        crc = crc32_reference_model(data_payload);
        $display("CRC: %0h", crc);
        
        /* Determine teh size of the payload */
        payload_size = data_payload.size();
        
        /* Initialize a packet to return */
        packet = new[payload_size + 8 + 4];     //Payload + 8 preamble bytes + 4 crc bytes
      
        /* Create Packet */
        
        //Ethernet Header + SFD
        for(int i = 0; i < 7; i++)
            packet[i] = ETH_HDR;
            
        packet[7] = ETH_SFD;
        
        //Payload
        for(int j = 0; j < payload_size; j++)
            packet[8 + j] = data_payload[j];
        
        //CRC Calculation
        for (int k = 0; k < 4; k++) 
            packet[8 + payload_size + k] = crc[(k*8 )+: 8]; 
                         
    endfunction : generate_pckt

endclass : rgmii_pckt

module rx_mac_tb;

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
    
    /* Variables */                                                    //Holds clock period ofor teh rgmii rx clk
    int clk_prd;
    
    /* Design Under Test Instantiation */
    rx_mac #(.DATA_WIDTH(DATA_WIDTH)) DUT (.*);  
    
    rgmii_pckt in_data;   
    
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
        
        foreach(in_data.packet[i]) begin           
            rgmii_mac_rx_data <= in_data.packet[i];
            rgmii_mac_rx_dv <= 1'b1;
            rgmii_mac_rx_er <= 1'b0;
            @(posedge clk);           
        end
        
        rgmii_mac_rx_dv <= 1'b0;
        
                
        #1000;
        $finish;
    end

endmodule
