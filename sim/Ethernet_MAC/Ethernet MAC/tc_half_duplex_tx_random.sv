`ifndef TC_WR_ONLY
`define TC_WR_ONLY

`include "eth_mac_base_test.sv"

///////////////////////////////////////////////////////////////////////////////////////////
// This testcase is used to test the operation of the ethernet MAC specifically in the 
// instance where the user will only be transmitting data. The link speed is randomized
// in this testcase as well as the number of packets transmitted.
///////////////////////////////////////////////////////////////////////////////////////////

class tc_half_duplex_tx_random extends eth_mac_base_test;
    `uvm_component_utils(tc_half_duplex_tx_random)

    eth_mac_tx_seq tx_seq;
    eth_mac_rx_seq rx_seq;    

    function new(string name = "tc_tx_random", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        int link_speed;
        super.build_phase(phase);

        //Instantiate sequences
        rx_seq = eth_mac_rx_seq::type_id::create("rx_seq");  
        tx_seq = eth_mac_tx_seq::type_id::create("tx_seq");          
        
        // Disable RX monitor for this test case
        cfg.disable_rx_monitor();  
        cfg.enable_tx_monitor(); 
        cfg.tx_burst_size = 1;
        link_speed = $urandom_range(0, 2);

        case(link_speed)
            0 : cfg.set_link_speed(cfg.GBIT_SPEED);
            1 : cfg.set_link_speed(cfg.MB_100_SPEED);
            2 : cfg.set_link_speed(cfg.MB_10_SPEED);
        endcase       

        cfg.set_link_speed(cfg.MB_100_SPEED);
                                                                                                         
    endfunction : build_phase
    
    task main_phase(uvm_phase phase);
        int num_packets;
        super.main_phase(phase);
        uvm_top.print_topology();

        phase.raise_objection(this);
        `uvm_info("tc_half_duplex_tx_random", "Objection raised - starting testcase", UVM_MEDIUM)

        //Send an rx_packet first to set the rgmii link speed - this is needed because we do not have an MDIO interface        
        rx_seq.start(env.rx_agent.rx_seqr);

        //Randomize number of packets to send
        num_packets = $urandom_range(10, 100);        

        //Set the total number of iterations for the scb
        env.eth_scb.num_tx_iterations = num_packets;

        //Send multiple tx packets on the rgmii interface
        repeat(num_packets) begin            
            tx_seq.start(env.tx_agent.tx_seqr);            
        end

        // Wait for scb to indicate it has receieved all packets before ending test      
        env.tx_scb_complete.wait_trigger();

        phase.drop_objection(this);

    endtask : main_phase    

endclass : tc_half_duplex_tx_random

`endif //TC_WR_ONLY