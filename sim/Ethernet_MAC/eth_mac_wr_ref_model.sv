`ifndef ETH_MAC_WR_REF_MODEL
`define ETH_MAC_WR_REF_MODEL

`include "uvm_macros.svh"  // Import UVM macros
import uvm_pkg::*;         // Import all UVM classes

class eth_mac_wr_ref_model extends uvm_component;
    `uvm_component_utils(eth_mac_wr_ref_model)

    /*Parameters */
    typedef logic [7:0] data_queue[$];
    localparam PADDING = 8'h00;
    localparam MIN_BYTES = 60;
    localparam HDR = 8'h55;
    localparam SFD = 8'hD5;

    //Recieve data from the driver via blocking TLM FIFO
    uvm_blocking_get_port#(eth_mac_wr_item)  i_driver_port;
    //Analysis export to transmit data to the scoreboard
    uvm_analysis_port#(eth_mac_wr_item) o_scb_port;

    function void new(string name = "wr_ref_model", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        /* Instantiate ports */
        i_driver_port = new("i_driver_port");
        o_scb_port = new("o_scb_port");
    endfunction : buildPhase

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

    function data_queue (input logic [7:0] driver_data[$]);
        int packet_size;
        logic [31:0] crc;
        logic [7:0] encapsulated_packet[$]; // Queue to return

        // Copy input queue to avoid modifying driver_data directly
        encapsulated_packet = driver_data; 

        packet_size = encapsulated_packet.size();

        // If the packet has less than MIN_BYTES, pad it
        while (packet_size < MIN_BYTES) begin
            encapsulated_packet.push_back(PADDING);
            packet_size++;
        end

        // Calculate CRC for the payload & append to the back
        crc = crc32_reference_model(encapsulated_packet);
        for (int i = 0; i < 4; i++) begin
            encapsulated_packet.push_back((crc >> (i * 8)) & 8'hFF); // Extract CRC bytes correctly
        end

        // Prepend the header & SFD
        for (int i = 7; i >= 0; i--) begin    
            if (i == 7)
                encapsulated_packet.push_front(SFD);
            else
                encapsulated_packet.push_front(HDR);
        end       

        return encapsulated_packet; // Return the modified queue

    endfunction : encapsulate_data

    virtual task main_phase(uvm_phase phase);
        //Two eth_items - One from the driver and the other to hold data after the
        // reference model has encapsulated it 
        eth_mac_wr_item driver_data, encap_data;        
        super.main_phase(phase);

        forever begin
            //Get data from driver - this is a blocking port
            i_driver_port.get(driver_data);

            //Simulate the ethernet tx encapsulation process
            encap_data = encapsulate_data(driver_data);

            //Transmit the encapsulated data to the scoreboard
            o_scb_port.write(encap_data);
        end

    endtask : main_phase

endclass : eth_mac_wr_ref_model

`endif //ETH_MAC_WR_REF_MODEL