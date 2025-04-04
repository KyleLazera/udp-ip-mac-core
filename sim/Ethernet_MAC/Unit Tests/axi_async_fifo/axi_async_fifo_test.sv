
`include "axi_stream_tx_bfm.sv"
`include "axi_stream_rx_bfm.sv"

import axi_async_fifo_pkg::*;

class axi_async_fifo_test;

/* Interface handles */
virtual axi_stream_tx_bfm tx;
virtual axi_stream_rx_bfm rx;

/* Constructor */
function new(virtual axi_stream_tx_bfm tx_if, virtual axi_stream_rx_bfm rx_if);
    this.tx = tx_if;
    this.rx = rx_if;
endfunction : new

/* Sanity Test - 1 write followed by 1 read */
task test_sanity();
    $display("Starting Test: test_sanity");
    
    repeat(10) begin
        generate_frame();
        tx.axis_transmit_basic(tx_frame);
        rx.axis_read(rx_frame);
        scoreboard();  
    end  

    $display("Complete Test: test_sanity");
endtask : test_sanity

/* Write and Read simultaneously */
task write_read();
    $display("Starting Test: write_read");

    fork
        begin
            //Write 10 packets into FIFO
            repeat(10) begin
                generate_frame();
                tx.axis_transmit_basic(tx_frame);
            end
        end
        begin
            //Make sure tvalid is high before starting
            wait(rx.m_axis_tvalid);
            while(rx.m_axis_tvalid) begin
                rx.axis_read(rx_frame); 
                scoreboard();
            end
        end   
    join

    $display("Complete Test: write_read");
endtask

endclass : axi_async_fifo_test