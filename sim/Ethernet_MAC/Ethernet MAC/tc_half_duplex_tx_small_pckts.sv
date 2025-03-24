`ifndef TX_SMALL_PCKTS
`define TX_SMALL_PCKTS

`include "eth_mac_base_test.sv"

class tc_half_duplex_tx_small_pckts extends eth_mac_base_test;
    `uvm_component_utils(tc_half_duplex_tx_small_pckts)

    eth_mac_tx_seq_small_pckts tx_seq;
    eth_mac_rx_seq rx_seq;    

    function new(string name = "tc_tx_small_pckts", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        int link_speed;
        super.build_phase(phase);

        //Instantiate sequences
        rx_seq = eth_mac_rx_seq::type_id::create("rx_seq");  
        //tx_seq = eth_mac_tx_seq::type_id::create("tx_seq");          
        tx_seq = eth_mac_tx_seq_small_pckts::type_id::create("tx_seq");

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

        cfg.set_link_speed(cfg.MB_10_SPEED);
                                                                                                         
    endfunction : build_phase
    
    task main_phase(uvm_phase phase);
        int num_packets;
        super.main_phase(phase);
        uvm_top.print_topology();

        phase.raise_objection(this);
        `uvm_info("tc_half_duplex_tx_small_pckts", "Objection raised - starting testcase", UVM_MEDIUM)

        //Randomize How many packets to send
        num_packets = $urandom_range(10, 100);

        //Send an rx_packet first to set the rgmii link speed        
        rx_seq.start(env.rx_agent.rx_seqr);

        //Set the total number of iterations for the scb
        env.eth_scb.num_tx_iterations = 10;

        //Send multiple tx packets on the rgmii interface
        repeat(10) begin            
            tx_seq.start(env.tx_agent.tx_seqr);            
        end

        // Wait for scb to indicate it has receieved all packets before ending test      
        env.tx_scb_complete.wait_trigger();

        phase.drop_objection(this);

    endtask : main_phase    

endclass : tc_half_duplex_tx_small_pckts

`endif //TX_SMALL_PCKTS