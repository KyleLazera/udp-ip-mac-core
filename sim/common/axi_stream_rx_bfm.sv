
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

    // Read data via AXI-Stream
    task axis_read(ref bit [7:0] data[$]);

        //Raise trdy flag to indicate we are redy to read data
        @(posedge m_aclk);
        m_axis_trdy <= 1'b1;
        @(posedge m_aclk);

        //Wait for the trdy flag to go high
        while(!m_axis_tvalid)
            @(posedge m_aclk);

        //Sample data on each clock edge
        while(!m_axis_tlast & (m_axis_tvalid & m_axis_trdy)) begin
            data.push_back(m_axis_tdata);
            @(posedge m_aclk);
        end
        
        data.push_back(m_axis_tdata);
        m_axis_trdy <= 1'b0;
        @(posedge m_aclk);

    endtask : axis_read

endinterface