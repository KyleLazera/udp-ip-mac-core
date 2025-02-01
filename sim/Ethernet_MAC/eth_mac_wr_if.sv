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
    logic s_tx_axis_trdy;                                 //Indicates to FIFO that it can read data (used to set rd_en for FIFIO)

    /* Clocking Block for input from TX FIFO */
    clocking tx_fifo_cb @(posedge clk_125);
        output s_tx_axis_tdata;
        output s_tx_axis_tvalid;
        output s_tx_axis_tlast;
        input  s_tx_axis_trdy;
    endclocking

    /* Clocking Block for RGMII Data Capture */
    clocking rgmii_cb @(posedge rgmii_phy_txc);
        input rgmii_phy_txd;
        input rgmii_phy_txctl;
    endclocking

    /* BFM Tasks */
    
    task tx_fifo_drive_data(logic [7:0] ref_fifo[$]);
        int fifo_size = ref_fifo.size();
        while (fifo_size > 0) begin
            @(tx_fifo_cb);
            if (tx_fifo_cb.s_tx_axis_trdy) begin
                tx_fifo_cb.s_tx_axis_tvalid <= 1;
                tx_fifo_cb.s_tx_axis_tdata <= ref_fifo.pop_back();
                tx_fifo_cb.s_tx_axis_tlast <= (fifo_size == 1);
                fifo_size--;
            end
        end
    endtask : tx_fifo_drive_data

    task read_rgmii_data(output logic[7:0] rgmii_data[$]);
        while (rgmii_cb.rgmii_phy_txctl) begin
            @(rgmii_cb);
            rgmii_data.push_back(rgmii_cb.rgmii_phy_txd);
        end
    endtask : read_rgmii_data

endinterface : eth_mac_wr_if

`endif // ETH_MAC_WR_IF