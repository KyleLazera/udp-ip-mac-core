`ifndef ETH_MAC_SCB
`define ETH_MAC_SCB

class eth_mac_scb extends uvm_scoreboard;
    `uvm_component_utils(eth_mac_scb)

    eth_mac_cfg cfg;
    int num_tx_iterations, num_rx_iterations;

    eth_mac_item eth_wr_data, eth_wr_ref_data;
    eth_mac_item rx_rgmii, rx_fifo;  

    int tx_packets_rec = 0, rx_packets_rec = 0;   

    /* Events */
    uvm_event tx_scb_complete;
    uvm_event rx_scb_complete;

    // Port to connect to tx agent 
    uvm_blocking_get_port#(eth_mac_item) tx_mon_port;
    uvm_blocking_get_port#(eth_mac_item) tx_drv_port;
    //Port to connect rx agent
    uvm_blocking_get_port#(eth_mac_item) rx_drv_port;
    uvm_blocking_get_port#(eth_mac_item) rx_mon_port;

    function new(string name = "eth_mac_scb", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Init the analysis port
        tx_mon_port = new("tx_mon_port", this);
        tx_drv_port = new("tx_drv_port", this);
        rx_drv_port = new("rx_drv_port", this);
        rx_mon_port = new("rx_mon_port", this);
    endfunction : build_phase

    task decode_packet(ref bit[7:0] packet[$]);
        bit [7:0] decode_byte = packet.pop_front();
        
        if(decode_byte == 8'h00 || decode_byte == 8'h01) begin
            rx_packets_rec++;

            if(decode_byte == 8'h00) begin
                `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)
                `uvm_info("scb", "RX Bad Packet Dropped", UVM_MEDIUM)
                `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)                 
            end else if(decode_byte == 8'h01) begin
                `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)
                `uvm_info("scb", "Pause Frame Receieved", UVM_MEDIUM)
                `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)   
            end

            rx_drv_port.get(rx_rgmii); 
            decode_packet(rx_rgmii.tx_data);

        end      
    
    endtask : decode_packet

    virtual task main_phase(uvm_phase phase);   
        super.main_phase(phase);

        fork
            /* RX scoreboard */
            begin
                forever begin
                        `uvm_info("scb", "rx monitor enabled", UVM_MEDIUM)

                        rx_mon_port.get(rx_fifo);
                        rx_drv_port.get(rx_rgmii);    

                        // Determine whether the packet we sent to teh MAC is expected to be read fromt eh FIFO or not
                        decode_packet(rx_rgmii.tx_data);                                           

                        //Make sure the reference model data size and the monitor data size are equivelent
                        assert(rx_fifo.rx_data.size() == rx_rgmii.tx_data.size()) begin
                            `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)
                            `uvm_info("scb", $sformatf("RX Driver Packet size: %0d == Monitor Packet size: %0d MATCH", rx_rgmii.tx_data.size(), rx_fifo.rx_data.size()), UVM_MEDIUM)
                            `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)
                            rx_packets_rec++;
                        end else  begin
                            `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)
                            `uvm_fatal("scb", $sformatf("RX Driver Packet size: %0d != Monitor Packet size: %0d MISMATCH", rx_rgmii.tx_data.size(), rx_fifo.rx_data.size()));
                            `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)
                        end
                                                 
                        foreach(rx_fifo.rx_data[i])
                            assert(rx_fifo.rx_data[i] == rx_rgmii.tx_data[i]) //`uvm_info("SCB", $sformatf("RX Monitor Data : %0h == RX Reference Data : %0h MATCH", rx_fifo.rx_data[i], rx_rgmii.tx_data[i]), UVM_MEDIUM)
                            else `uvm_error("scb", $sformatf("RX Monitor Data : %0h != RX Reference Data : %0h MISMATCH", rx_fifo.rx_data[i], rx_rgmii.tx_data[i]));  

                        `uvm_info("scb", $sformatf("%0d out of %0d Packets Recieved", rx_packets_rec, num_rx_iterations), UVM_MEDIUM)  

                        if(rx_packets_rec == num_rx_iterations) begin                              
                            rx_scb_complete.trigger();                                        
                        end                                

                end
            end
            /* TX scoreboard */
            begin
                forever begin
                        //Fetch teh data from the monitor FIFO              
                        tx_mon_port.get(eth_wr_data);        
                        //Fetch the data from the reference model FIFO
                        tx_drv_port.get(eth_wr_ref_data);                            

                        assert(eth_wr_data.rx_data.size() == eth_wr_ref_data.tx_data.size()) begin
                            `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)
                            `uvm_info("scb", $sformatf("TX Driver Packet size: %0d == Monitor Packet size: %0d MATCH", eth_wr_ref_data.tx_data.size(), eth_wr_data.rx_data.size()), UVM_MEDIUM)
                            `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)
                            tx_packets_rec++;
                        end else  begin
                            `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)
                            `uvm_fatal("scb", $sformatf("TX Driver Packet size: %0d != Monitor Packet size: %0d MISMATCH", eth_wr_ref_data.tx_data.size(), eth_wr_data.rx_data.size()));
                            `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)
                        end               
                
                        foreach(eth_wr_ref_data.tx_data[i])
                            assert(eth_wr_data.rx_data[i] == eth_wr_ref_data.tx_data[i]) //`uvm_info("SCB", $sformatf("TX Monitor Data : %0h == TX Reference Data : %0h MATCH", eth_wr_data.rx_data[i], eth_wr_ref_data.tx_data[i]), UVM_MEDIUM)
                            else `uvm_fatal("scb", $sformatf("TX Monitor Data : %0h != TX Reference Data : %0h MISMATCH", eth_wr_data.rx_data[i], eth_wr_ref_data.tx_data[i]));        
                
                        `uvm_info("scb", $sformatf("%0d out of %0d Packets Recieved", tx_packets_rec, num_tx_iterations), UVM_MEDIUM)  

                        if(tx_packets_rec == num_tx_iterations)
                            tx_scb_complete.trigger();
                end
            end
        join

    endtask : main_phase

endclass : eth_mac_scb

`endif //ETH_MAC_SCB