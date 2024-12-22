`ifndef _TX_MAC_SEQ
`define _TX_MAC_SEQ

class tx_mac_seq extends uvm_sequence#(tx_mac_trans_item);
    `uvm_object_utils(tx_mac_seq)
    
    rand int packet_size;
    
    function new(string name = "tx_mac_seq");
        super.new(name);
    endfunction : new
    
    virtual task body();
        tx_mac_trans_item   tx_item = tx_mac_trans_item::type_id::create("tx_item");
        logic [7:0] data_byte;
        
        //Randomize the size of the packet
        packet_size = $urandom_range(20, 1500);

        /* Packet Generation Algorithm */
         for(int i = 0; i < packet_size; i++) begin           
             /* Randomize the byte value */
             data_byte = $urandom_range(0, 255);
             
             /* Push the value to back of the queue */
             tx_item.payload.push_back(data_byte);
             
             /* Populate the last byte queue if we are on last iteration*/
             if(i == (packet_size - 1))
                 tx_item.last_byte.push_back(1'b1);
             else
                 tx_item.last_byte.push_back(1'b0);
        end
        
        //Ensure the last byte and payload queues are same size
        assert(tx_item.last_byte.size() == tx_item.payload.size()) 
                else `uvm_fatal("TX_MAC_SEQ", "Size mismatch for last byte and payload queue");                             
                
        // Send the sequence item to the driver
        start_item(tx_item);
        finish_item(tx_item);

        // Reset queues for the next packet
        tx_item.payload.delete();
        tx_item.last_byte.delete();                
        
    endtask : body
    
endclass : tx_mac_seq

`endif //_TX_MAC_SEQ
