`ifndef ETH_MAC_SCB
`define ETH_MAC_SCB

class eth_mac_scb extends uvm_scoreboard;
    `uvm_component_utils(eth_mac_scb)

    eth_mac_cfg cfg;

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

    //todo: Change the conditional to a fork to have 2 processes so we can run read/writes simultaneously
    virtual task main_phase(uvm_phase phase);
        eth_mac_item eth_wr_data, eth_wr_ref_data;
        eth_mac_item rx_rgmii, rx_fifo;
        super.main_phase(phase);

        fork
            /* RX scoreboard */
            begin
                forever begin
                        `uvm_info("scb", "rx monitor enabled", UVM_MEDIUM)

                        rx_mon_port.get(rx_fifo);
                        rx_drv_port.get(rx_rgmii);

                        //Make sure the reference model data size and the monitor data size are equivelent
                        assert(rx_fifo.rx_data.size() == rx_rgmii.tx_data.size()) begin
                            `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)
                            `uvm_info("scb", $sformatf("RX Driver Packet size: %0d == Monitor Packet size: %0d MATCH", rx_rgmii.tx_data.size(), rx_fifo.rx_data.size()), UVM_MEDIUM)
                            `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)
                        end else  begin
                            `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)
                            `uvm_fatal("scb", $sformatf("RX Driver Packet size: %0d != Monitor Packet size: %0d MISMATCH", rx_rgmii.tx_data.size(), rx_fifo.rx_data.size()));
                            `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)
                        end
                
                        foreach(rx_fifo.rx_data[i])
                            assert(rx_fifo.rx_data[i] == rx_rgmii.tx_data[i]) `uvm_info("SCB", $sformatf("RX Monitor Data : %0h == RX Reference Data : %0h MATCH", rx_fifo.rx_data[i], rx_rgmii.tx_data[i]), UVM_MEDIUM)
                            else `uvm_error("scb", $sformatf("RX Monitor Data : %0h != RX Reference Data : %0h MISMATCH", rx_fifo.rx_data[i], rx_rgmii.tx_data[i]));
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
                            `uvm_info("scb", $sformatf("TX Driver Packet size: %0d == Monitor Packet size: %0d MATCH",  eth_wr_data.rx_data.size(), eth_wr_ref_data.tx_data.size()), UVM_MEDIUM)
                            `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)
                        end else  begin
                            `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)
                            `uvm_fatal("scb", $sformatf("TX Driver Packet size: %0d != Monitor Packet size: %0d MISMATCH",  eth_wr_data.rx_data.size(), eth_wr_ref_data.tx_data.size()));
                            `uvm_info("scb", "----------------------------------------------------------------", UVM_MEDIUM)
                        end                    
                
                        foreach(eth_wr_ref_data.tx_data[i])
                            assert(eth_wr_data.rx_data[i] == eth_wr_ref_data.tx_data[i]) `uvm_info("SCB", $sformatf("TX Monitor Data : %0h == TX Reference Data : %0h MATCH", eth_wr_data.rx_data[i], eth_wr_ref_data.tx_data[i]), UVM_MEDIUM)
                            else `uvm_error("scb", $sformatf("TX Monitor Data : %0h != TX Reference Data : %0h MISMATCH", eth_wr_data.rx_data[i], eth_wr_ref_data.tx_data[i]));            
                end
            end
        join

    endtask : main_phase

endclass : eth_mac_scb

`endif //ETH_MAC_SCB