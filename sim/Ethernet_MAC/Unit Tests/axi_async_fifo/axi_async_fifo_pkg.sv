
`include "axi_stream_rx_bfm.sv"
`include "axi_stream_tx_bfm.sv"


package axi_async_fifo_pkg;

/* Variables */
bit [7:0] tx_frame[$];
bit [7:0] rx_frame[$];
bit [7:0] ref_frame[$];

/* Methods */

// Used to generate a random frame of varying size
function void generate_frame();
    int pckt_size = $urandom_range(10, 500);

    //Clear current frame
    tx_frame.delete();
    //generate random frame with random size
    for(int i = 0; i < pckt_size; i++) begin
        bit [7:0] data_byte = $urandom_range(0, 255);
        tx_frame.push_back(data_byte);
        ref_frame.push_back(data_byte);
    end

endfunction : generate_frame

function void scoreboard();
        
    //Self Checking logic 
    foreach(rx_frame[i]) begin
        bit [7:0] rx_byte = ref_frame.pop_front();
        assert(rx_frame[i] == rx_byte) else begin
            $display("Mismatch in data: rx_frame %0h != ref data %0h", rx_frame[i], rx_byte);
            $stop;
        end
    end
    
    rx_frame.delete();
endfunction : scoreboard


endpackage : axi_async_fifo_pkg