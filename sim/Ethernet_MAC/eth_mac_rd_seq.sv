`ifndef ETH_MAC_RD_SEQ
`define ETH_MAC_RD_SEQ

`include "eth_mac_wr_item.sv"

class eth_mac_rd_seq extends uvm_sequence#(eth_mac_rd_item);
    `uvm_object_utils(eth_mac_rd_seq)

    logic [7:0] tx_fifo[$];
    logic [7:0] tx_byte;    

    function new(string name = "eth_mac_rd_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        int packet_size;
        eth_mac_wr_item tx_item;

        packet_size = $urandom_range(10, 1500);
        tx_item = eth_mac_wr_item::type_id::create("tx_item");

        /* Populate the tx_fifo with random data */
        for(int i = 0; i < packet_size; i++) begin
            tx_byte = $urandom_range(0, 255);
            tx_item.tx_fifo.push_back(tx_byte);                        
        end        

        start_item(tx_item);
        
        `uvm_info("wr_seq", "Data sent to driver", UVM_MEDIUM)
        
        finish_item(tx_item);

        `uvm_info("wr_seq", "finished_item called, ready for more data", UVM_MEDIUM)

    endtask : body

endclass : eth_mac_wr_seq

`endif //ETH_MAC_WR_SEQ