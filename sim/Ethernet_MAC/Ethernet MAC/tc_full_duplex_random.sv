`ifndef TC_FULL_DUPLEX
`define TC_FULL_DUPLEX

`include "eth_mac_base_test.sv"

//Test case for sequence above
class tc_full_duplex_random extends eth_mac_base_test;
    `uvm_component_utils(tc_full_duplex_random)

    eth_mac_tx_seq tx_seq;
    eth_mac_rx_seq rx_seq;     

    function new(string name = "tx_rd_wr", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        int link_speed;
        super.build_phase(phase);

        //Instantiate sequences
        rx_seq = eth_mac_rx_seq::type_id::create("rx_seq");  
        tx_seq = eth_mac_tx_seq::type_id::create("tx_seq");         

        cfg.enable_rx_monitor();
        cfg.enable_tx_monitor();
        cfg.enable_rx_bad_pckt();
        cfg.pause_frames = 1'b1;
        //cfg.tx_burst_size = 1; 
        link_speed = $urandom_range(0, 2);

        /*case(link_speed)
            0 : cfg.set_link_speed(cfg.GBIT_SPEED);
            1 : cfg.set_link_speed(cfg.MB_100_SPEED);
            2 : cfg.set_link_speed(cfg.MB_10_SPEED);
        endcase*/

        cfg.set_link_speed(cfg.MB_100_SPEED);
                                                                 
    endfunction : build_phase
    
    task main_phase(uvm_phase phase);
        int num_tx_packets, num_rx_packets;
        super.main_phase(phase);
        uvm_top.print_topology();

        phase.raise_objection(this);

        //Send an rx_packet first to set the rgmii link speed - this is needed because we do not have an MDIO interface        
        rx_seq.start(env.rx_agent.rx_seqr);

        //Randomize number of packets to send
        num_tx_packets = $urandom_range(50, 100);   
        num_rx_packets = $urandom_range(50, 70);        

        //Set the total number of iterations for the scb - because we transmit an rx packet early, increment
        // the total number of rx packets that will be recieved so the scb takes it into account
        env.eth_scb.num_tx_iterations = num_tx_packets;
        env.eth_scb.num_rx_iterations = num_rx_packets + 1;

        //Drive data in full duplex mode 
        fork
            begin
                repeat(num_tx_packets)
                    tx_seq.start(env.tx_agent.tx_seqr);
            end
            begin
                //Send multiple rx packets on the rgmii interface using bad packets
                for(int i = 0; i < num_rx_packets; i++) begin

                        // Make sure teh final iteration sends a good packet, this will prevent the monitor
                        // from stalling while waiting for the final packet
                        if((i+1) == num_rx_packets)
                            cfg.disable_rx_bad_pckt();

                        rx_seq.start(env.rx_agent.rx_seqr);                            
                end
            end
        join        

        // Wait for scb to indicate it has receieved all packets before ending test      
        env.tx_scb_complete.wait_on();
        env.rx_scb_complete.wait_on();

        phase.drop_objection(this);    

    endtask : main_phase    

endclass : tc_full_duplex_random


`endif //TC_FULL_DUPLEX