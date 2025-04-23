
interface axi_stream_rx_bfm #(
    parameter AXI_DATA_WIDTH = 8
)
(
    input bit m_aclk,
    input bit m_sresetn
);

    reg [AXI_DATA_WIDTH-1:0] m_axis_tdata;
    reg m_axis_tlast;
    reg m_axis_tvalid;
    reg m_axis_trdy;

    // Used to initialize values to avoid Dont Cares
    task init_axi_rx();
        m_axis_trdy = 1'b0;
    endtask : init_axi_rx

    // Reads data via the AXI-Stream protocol
    task axis_read(ref bit [7:0] data[$]);

        //Raise trdy flag 
        @(posedge m_aclk);
        m_axis_trdy <= 1'b1;
        @(posedge m_aclk);

        //If tvalid flag is not high, wait until it is
        while(!m_axis_tvalid)
            @(posedge m_aclk);

        //Sample data on each clock edge
        while(!m_axis_tlast & m_axis_tvalid) begin
            int deassert_trdy = ($urandom_range(0, 20) == 1);

            if(m_axis_trdy)
                data.push_back(m_axis_tdata);
            
            // Periodically de-assert trdy - this is used to make sure the modules being tested
            // do not transmit data if trdy is lowered.
            m_axis_trdy <= !deassert_trdy;

            @(posedge m_aclk);
        end
        
        data.push_back(m_axis_tdata);
        m_axis_trdy <= 1'b0;
        @(posedge m_aclk);

    endtask : axis_read

endinterface