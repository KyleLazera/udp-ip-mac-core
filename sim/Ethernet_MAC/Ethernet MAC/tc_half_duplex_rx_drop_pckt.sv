`ifndef TC_DROP_PCKT
`define TC_DROP_PCKT

`include "eth_mac_base_test.sv"

//TODO: randomize number of packets to send
class tc_half_duplex_rx_drop_pckt extends eth_mac_base_test;
    `uvm_component_utils(tc_half_duplex_rx_drop_pckt)

    eth_mac_rx_seq rx_seq;

    function new(string name = "tc_rx_bad_pckt", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        int link_speed;
        super.build_phase(phase);

        //Instantiate sequences
        rx_seq = eth_mac_rx_seq::type_id::create("rx_seq");            

        cfg.enable_rx_monitor(); 
        //Enable transmission of packets with crc errors/data errors 
        cfg.enable_rx_bad_pckt();
        link_speed = $urandom_range(0, 2);

        /*case(link_speed)
            0 : cfg.set_link_speed(cfg.GBIT_SPEED);
            1 : cfg.set_link_speed(cfg.MB_100_SPEED);
            2 : cfg.set_link_speed(cfg.MB_10_SPEED);
        endcase   */

        cfg.set_link_speed(cfg.MB_10_SPEED);               
                                                                    
    endfunction : build_phase
    
    task main_phase(uvm_phase phase);
        int num_packets;
        super.main_phase(phase);
        uvm_top.print_topology();

        phase.raise_objection(this);

        //Randomize number of packets to send
        num_packets = $urandom_range(10,100);        

        //Set the total number of iterations for the scb
        env.eth_scb.num_rx_iterations = num_packets;

        //Send multiple tx packets on the rgmii interface
        for(int i = 0; i < num_packets; i++) begin

            // Make sure teh final iteration sends a good packet, this will prevent the monitor
            // from stalling because it does not identify a bad packet
            if((i+1) == num_packets)
                cfg.disable_rx_bad_pckt();

            rx_seq.start(env.rx_agent.rx_seqr);            
        end

        // Wait for scb to indicate it has receieved all packets before ending test      
        env.rx_scb_complete.wait_on();

        phase.drop_objection(this);

    endtask : main_phase    

endclass : tc_half_duplex_rx_drop_pckt

`endif // TC_DROP_PCKT