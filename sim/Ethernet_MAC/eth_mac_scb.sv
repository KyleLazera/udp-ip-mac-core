`ifndef ETH_MAC_SCB
`define ETH_MAC_SCB

class eth_mac_scb extends uvm_scoreboard;
    `uvm_component_utils(eth_mac_scb)

    // Port to connect to eth_wr agent monitor
    uvm_blocking_get_port#(eth_mac_wr_item) eth_wr_import;
    //Port to connect eth_wr agent ref model
    uvm_blocking_get_port#(eth_mac_wr_item) eth_wr_ref;

    function void new(string name = "eth_mac_scb", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //Init the analysis port
        eth_wr_import = new("eth_wr_import");
        eth_wr_ref = new("eth_wr_ref");
    endfunction : build_phase

    virtual task main_phase(uvm_phase phase);
        eth_mac_wr_item eth_wr_data, eth_wr_ref_data;
        super.main_phase(phase);
        
        forever begin
            //Fetch the data from the monitor and teh reference model
            eth_wr_import.get(eth_wr_data);
            eth_wr_ref.get(eth_wr_ref_data);

            //Compare the rgmii output of teh 2 values
            assert(eth_wr_data.rgmii_data_q == eth_wr_ref.rgmii_data_q) else `uvm_error("scb", "Data did not macth");
        end

    endtask : main_phase

endclass : eth_mac_scb

`endif //ETH_MAC_SCB