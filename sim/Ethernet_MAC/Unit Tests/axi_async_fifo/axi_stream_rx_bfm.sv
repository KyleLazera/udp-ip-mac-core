
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
            if(m_axis_trdy)
                data.push_back(m_axis_tdata);

            @(posedge m_aclk);
        end
        
        data.push_back(m_axis_tdata);
        m_axis_trdy <= 1'b0;
        @(posedge m_aclk);

    endtask : axis_read

endinterface