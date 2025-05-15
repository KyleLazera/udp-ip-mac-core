
interface axi_stream_tx_bfm #(
    parameter AXI_DATA_WIDTH = 8
)
(
    input bit s_aclk,
    input bit s_sresetn
);

    reg [AXI_DATA_WIDTH-1:0] s_axis_tdata;
    reg s_axis_tlast;
    reg s_axis_tvalid;
    reg s_axis_tuser;
    reg s_axis_trdy;

    /* This task is a basic transmission test that pulls the valid flag low temporarily
     * after sending a frame & keeps tuser low for the entire duration*/
    task axis_transmit_basic(bit [7:0] data[$]);

        //Raise tvalid flag to indicate we are ready to transmit
        @(posedge s_aclk);
        s_axis_tvalid <= 1'b1;
        s_axis_tdata <= data.pop_front;
        s_axis_tuser <= 1'b0;

        //Wait for the trdy flag to go high
        while(!s_axis_trdy)
            @(posedge s_aclk);

        //Transmit data on each clock edge
        while(data.size() != 0) begin
            // AXI-Stream Handshake
            if(s_axis_tvalid & s_axis_trdy) begin
                s_axis_tdata <= data.pop_front;
                s_axis_tlast <= (data.size() == 0); 
            end
            @(posedge s_aclk);
        end

        // In the instance where s_trdy was low when sending the last byte
        // we need to wait until s_trdy is valid
        while(!s_axis_trdy)
            @(posedge s_aclk);
        
        s_axis_tvalid <= 1'b0;
        s_axis_tlast <= 1'b0;
        @(posedge s_aclk);

    endtask : axis_transmit_basic

endinterface