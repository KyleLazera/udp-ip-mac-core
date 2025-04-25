`ifndef RGMII_TX_BFM
`define RGMII_TX_BFM

/* 
 * This interface is used to simulate users writing data into the tx fifo and read/monitor
 * the output signals on the RGMII signals 
 */ 

interface rgmii_tx_bfm;    
  

    /* Parameters */
    localparam RGMII_DATA_WIDTH = 4;
    localparam AXI_DATA_WIDTH = 8;
    
    /* DUT Signals */
    logic rgmii_phy_txc;                                  //Outgoing data clock signal
    logic [RGMII_DATA_WIDTH-1:0] rgmii_phy_txd;           //Outgoing ethernet packet data
    logic rgmii_phy_txctl;                                //Outgoing control signal (dv ^ er)

    /* BFM Tasks */

    task read_rgmii_data(output bit[7:0] rgmii_data[$], bit [1:0] link_speed);
        bit [7:0] queue[$];
        
        @(posedge rgmii_phy_txctl);
        while (rgmii_phy_txctl) begin
            logic [3:0] lower_nibble, upper_nibble;
            logic [7:0] sampled_byte;
            
            @(posedge rgmii_phy_txc);

            if(rgmii_phy_txctl) begin
                lower_nibble = rgmii_phy_txd;

                if(link_speed == 2'b00)
                    @(negedge rgmii_phy_txc);  
                else
                    @(posedge rgmii_phy_txc);

                upper_nibble = rgmii_phy_txd;
                sampled_byte = {upper_nibble, lower_nibble};            
                rgmii_data.push_back(sampled_byte);
            end
        end

        rgmii_data = queue;
        
    endtask : read_rgmii_data 

endinterface : rgmii_tx_bfm

`endif // RGMII_TX_BFM