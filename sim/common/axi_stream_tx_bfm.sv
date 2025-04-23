
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

    // Used to initialize values to avoid Dont Cares
    task init_axi_tx();
        s_axis_tdata = 1'b0;
        s_axis_tvalid = 1'b0;
        s_axis_tlast = 1'b0;
    endtask : init_axi_tx

    // Task to transmit data via AXI-Stream - arguments as follows:
    // data - Data to transmit via AXI-Stream
    // bursts - When 1, valid flag is held high between frames and when 0, valid is lowered between frames
    // fwft - follows fwft procedure
    task axis_transmit_basic(bit [7:0] data[$], bit bursts = 1'b1, fwft = 1'b1);

        //Raise tvalid & tuser flag to indicate we are ready to transmit
        @(posedge s_aclk);
        s_axis_tlast <= 1'b0;
        s_axis_tvalid <= 1'b1;
        s_axis_tuser <= 1'b0;

        //Put word on the tdata line if fwft
        if(fwft)
            s_axis_tdata <= data.pop_front();

        //Wait for the trdy flag to go high
        while(!s_axis_trdy)
            @(posedge s_aclk);

        //Transmit data on each clock edge if the tvalid and trdy signals are high
        while(data.size() != 0) begin
            if(s_axis_trdy & s_axis_tvalid) begin
                s_axis_tdata <= data.pop_front();
                s_axis_tlast <= (data.size() == 0);
            end
            @(posedge s_aclk);
        end
        
        while(!s_axis_trdy)
            @(posedge s_aclk);

        // If bursts is enabled, don't lower the valid flag
        if(!bursts)
            s_axis_tvalid <= 1'b0;

        @(posedge s_aclk);

    endtask : axis_transmit_basic

endinterface