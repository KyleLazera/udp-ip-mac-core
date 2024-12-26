`ifndef TX_MAC_MODEL
`define TX_MAC_MODEL

class tx_mac_model extends uvm_component;
    `uvm_component_utils(tx_mac_model)
    
    localparam DATA_WIDTH = 8;
    localparam CRC_WIDTH = 32;
    localparam TABLE_DEPTH = (2**DATA_WIDTH);
    
    //LUT Declaration
    logic [CRC_WIDTH-1:0] crc_lut [TABLE_DEPTH-1:0]; 
    logic [31:0] crc;       
    
    /* Anlaysis port - sends data to the scoreboard */
    uvm_analysis_port#(tx_mac_trans_item) wr_ap;
    /* Blocking port - Recieves data from the rx_mac_agent (blocks until rx_mac_agent has data to send) */
    uvm_blocking_get_port#(tx_mac_trans_item) port;    
    
    function new(string name = "tx_mac_model", uvm_component parent);
        super.new(name, parent);
    endfunction : new
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        //init the analysis ports
        wr_ap = new("wr_analysis_port", this);
        port = new("wr_blocking_port", this);
    endfunction : build_phase
    
    virtual task run_phase(uvm_phase phase);
        tx_mac_trans_item tx_item, copy_item;
        super.run_phase(phase);
        
        //LUT Init
        $readmemb("C:/Users/klaze/Xilinx_FGPA_Projects/FPGA_Based_Network_Stack/Software/CRC_LUT.txt", crc_lut);        
        
        forever begin
            //Get data from the rx_mac driver
            port.get(tx_item);
            
            copy_item = new("copy_tx_item");
            copy_item.payload = tx_item.payload;
            
            /* Determine Payload size and if padding is needed */
            while(copy_item.payload.size() < 60)
                copy_item.payload.push_back(8'h00);              
                
            /* Calculate and append the CRC */
            crc =  crc32_reference_model(copy_item.payload);
            
            for(int i = 0; i < 4; i++) 
                copy_item.payload.push_back(crc[i*8 +: 8]);
            
            /* Prepend preamble to data */
            for(int i = 7; i >= 0; i--) begin
                
                if(i == 7)
                    copy_item.payload.push_front(8'hD5);
                else
                    copy_item.payload.push_front(8'h55);
            end
                                 
            //Send new packet to scoreboard
            wr_ap.write(copy_item);       
        
        end
    endtask : run_phase
    
     /*
     * @Brief Reference Model that implements the CRC32 algorithm for each byte passed into it
     * @param i_byte Takes in a byte stream to pass into the model
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
    
endclass : tx_mac_model

`endif //TX_MAC_MODEL
