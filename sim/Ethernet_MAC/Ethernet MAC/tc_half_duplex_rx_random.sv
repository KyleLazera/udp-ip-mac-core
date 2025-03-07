`ifndef TC_RD_ONLY
`define TC_RD_ONLY

`include "eth_mac_base_test.sv"

//TODO: randomize number of packets to send
class tc_half_duplex_rx_random extends eth_mac_base_test;
    `uvm_component_utils(tc_half_duplex_rx_random)

    eth_mac_rx_seq rx_seq;

    function new(string name = "tc_rd_only", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        int link_speed;
        super.build_phase(phase);

        //Instantiate sequences
        rx_seq = eth_mac_rx_seq::type_id::create("rx_seq");            

        cfg.enable_rx_monitor();  
        link_speed = $urandom_range(0, 2);

        /*case(link_speed)
            0 : cfg.set_link_speed(cfg.GBIT_SPEED);
            1 : cfg.set_link_speed(cfg.MB_100_SPEED);
            2 : cfg.set_link_speed(cfg.MB_10_SPEED);
        endcase   */

        cfg.set_link_speed(cfg.GBIT_SPEED);               
                                                                    
    endfunction : build_phase
    
    task main_phase(uvm_phase phase);
        int num_packets;
        super.main_phase(phase);
        uvm_top.print_topology();

        phase.raise_objection(this);

        //Randomize number of packets to send
        num_packets = 10;        

        //Set the total number of iterations for the scb
        env.eth_scb.num_iterations = num_packets;

        //Send multiple tx packets on the rgmii interface
        repeat(num_packets) begin            
            rx_seq.start(env.rx_agent.rx_seqr);            
        end

        // Wait for scb to indicate it has receieved all packets before ending test      
        env.rx_scb_complete.wait_on();

        phase.drop_objection(this);

    endtask : main_phase    

endclass : tc_half_duplex_rx_random

`endif // TC_RD_ONLY