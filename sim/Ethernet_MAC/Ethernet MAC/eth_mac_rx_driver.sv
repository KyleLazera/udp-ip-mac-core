`ifndef ETH_MAC_RX_DRV
`define ETH_MAC_RX_DRV

`include "eth_mac.sv"

class eth_mac_rx_driver extends uvm_driver#(eth_mac_item);
`uvm_component_utils(eth_mac_rx_driver)

eth_mac_cfg cfg;

uvm_analysis_port#(eth_mac_item) drv_scb_port;
virtual eth_mac_rd_if rd_if;
string TAG = "eth_mac_rx_driver";

function new(string name = "eth_mac_rx_driver", uvm_component parent);
    super.new(name, parent);
endfunction : new

virtual function void build_phase(uvm_phase phase);    
    super.build_phase(phase);
    //Fetch Virtual interface
    if(!uvm_config_db#(virtual eth_mac_rd_if)::get(this, "", "eth_mac_rd_if", rd_if))
        `uvm_fatal(TAG, "Failed to fecth rd virtual interface");   

    drv_scb_port = new("drv_scb_port", this);
endfunction : build_phase

virtual task main_phase(uvm_phase phase);
    eth_mac_item tx_item, tx_item_copy;
    eth_mac eth_mac_base;
    bit crc_er = 1'b0;
    bit bad_pckt;
    super.main_phase(phase);    

    /* Instantiate instace of eth_mac for simulation */
    eth_mac_base = eth_mac::type_id::create("eth_mac_base");

    //Start the rxc on the RGMII line - Used for autonegotiation
    fork
        rd_if.generate_clock(cfg.link_speed); 
    join_none
    

    @(posedge rd_if.reset_n);

    #1000;

    forever begin        
        bad_pckt = 1'b0;

        if(cfg.rx_bad_pckt) begin
            //Randomize these values with a distribution
            crc_er = ($urandom_range(1, 100) == 1);
        end

        tx_item_copy = eth_mac_item::type_id::create("tx_item_copy");
        //Fetch sequence item to write
        seq_item_port.get_next_item(tx_item);
        //Copy data to send to the screoboard for reference
        tx_item_copy.copy(tx_item);

        //Switch the endianess of teh data and if teh packet is less than 60 bytes add padding
        if(tx_item_copy.tx_data.size() < 60) 
            eth_mac_base.pad_packet(tx_item_copy.tx_data);
        else
            tx_item_copy.tx_data = {<<8{tx_item_copy.tx_data}};

        //Encapsulate data before sending on RGMII
        eth_mac_base.encapsulate_data(tx_item.tx_data); 

        //Append a bad CRC Value to end of the Packet if we have teh configuration set to bad packet
        if(cfg.rx_bad_pckt & crc_er) begin
            bit [7:0] bad_crc_byte = $urandom_range(0, 255);
            `uvm_info("rx_driver", "Bad CRC Appended", UVM_MEDIUM)            
            tx_item.tx_data.pop_back();
            tx_item.tx_data.push_back(bad_crc_byte);
            bad_pckt = 1'b1;
        end

        //Drive data on the RGMII signals to the MAC
        rd_if.rgmii_drive_data(tx_item.tx_data, cfg.link_speed, cfg.rx_bad_pckt, bad_pckt);   

        //If it is a bad packet, append a 0x00 to teh front of teh queue and if it is not a bad packet
        // append 0xff
        if(bad_pckt) begin
            tx_item_copy.tx_data.push_front(8'h00);
        end else
            tx_item_copy.tx_data.push_front(8'hff);

        //Send copied data to the scoreboard
        drv_scb_port.write(tx_item_copy);           

        //Signal seqr for more data    
        seq_item_port.item_done();
    end 
endtask : main_phase

endclass : eth_mac_rx_driver

`endif //ETH_MAC_RX_DRV