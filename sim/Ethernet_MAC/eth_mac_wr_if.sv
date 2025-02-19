`ifndef ETH_MAC_WR_IF
`define ETH_MAC_WR_IF

/* 
 * This interface is used to simulate users writing data into the tx fifo and read/monitor
 * the output signals on the RGMII signals 
 */

interface eth_mac_wr_if
(
    input bit clk_125, 
    input bit clk90_125, 
    input bit reset_n
);
    /* Parameters */
    localparam RGMII_DATA_WIDTH = 4;
    localparam FIFO_DATA_WIDTH = 8;
    
    /* DUT Signals */
    //RGMII Read Signals
    logic rgmii_phy_txc;                                  //Outgoing data clock signal
    logic [RGMII_DATA_WIDTH-1:0] rgmii_phy_txd;           //Outgoing ethernet packet data
    logic rgmii_phy_txctl;                                //Outgoing control signal (dv ^ er)
    //TX FIFO Signals 
    logic [FIFO_DATA_WIDTH-1:0] s_tx_axis_tdata;           //Incoming bytes of data from the FIFO    
    logic s_tx_axis_tvalid;                                //Indicates FIFO has valid data (is not empty)
    logic s_tx_axis_tlast;                                 //Indicates last beat of transaction (final byte in packet)
    logic s_tx_axis_trdy;                                  //Indicates to FIFO that it can read data (used to set rd_en for FIFIO)

    /* Clocking Block for input from TX FIFO */
    clocking tx_fifo_cb @(posedge clk_125);
        output s_tx_axis_tdata;
        output s_tx_axis_tvalid;
        output s_tx_axis_tlast;
        input  s_tx_axis_trdy;
    endclocking

    /* BFM Tasks */
    
    //This simulates a FIFO driving data into the module
    task tx_fifo_drive_data(bit [7:0] ref_fifo[$]);
        int fifo_size = ref_fifo.size();
        
        //Wait for the tx mac to indciate it is ready to recieve data
        @(tx_fifo_cb.s_tx_axis_trdy);
        //Drive the data out of the FIFO
        while (fifo_size > 0) begin
            tx_fifo_cb.s_tx_axis_tvalid <= 1;
            @(tx_fifo_cb);         
            if (tx_fifo_cb.s_tx_axis_trdy) begin  
                tx_fifo_cb.s_tx_axis_tlast <= (fifo_size == 1);              
                tx_fifo_cb.s_tx_axis_tdata <= ref_fifo.pop_back();
                fifo_size--;
            end
        end
        
        @(tx_fifo_cb);
        tx_fifo_cb.s_tx_axis_tlast <= (fifo_size == 1);
    endtask : tx_fifo_drive_data

    //Currently only supports 1gbit operation reading - DDR
    task read_rgmii_data(ref bit[7:0] rgmii_data[$]);
        @(posedge rgmii_phy_txctl);
        while (rgmii_phy_txctl) begin
            logic [3:0] pos_edge, neg_edge;
            logic [7:0] sampled_byte;
            @(posedge rgmii_phy_txc);
            //Before sampling ensure the ctl signal is high. The reason for this is because the ctl signal is synchronized to the
            // clk_125, therefore, the ctl signal will only go low at the next clk_125 edge after all data has been transmitted. This
            // could lead to the while loop iterating one extra time and sampling one extra byte of data. This conditional helps avoid this.
            if(rgmii_phy_txctl) begin
                pos_edge = rgmii_phy_txd;
                @(negedge rgmii_phy_txc);        
                neg_edge = rgmii_phy_txd;
                sampled_byte = {neg_edge, pos_edge};            
                rgmii_data.push_back(sampled_byte);
            end
        end
        
    endtask : read_rgmii_data

endinterface : eth_mac_wr_if

`endif // ETH_MAC_WR_IF