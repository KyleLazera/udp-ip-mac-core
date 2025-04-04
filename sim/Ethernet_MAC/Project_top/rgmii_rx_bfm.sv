
/* Bus Functional Model for the RGMII rx interface - this drives data
 * on the RGMII line into the ethernet MAC
 */

interface rgmii_rx_bfm;
    localparam RGMII_DATA_WIDTH = 4;

    logic rgmii_phy_rxc;                                  
    logic [RGMII_DATA_WIDTH-1:0] rgmii_phy_rxd;            
    logic rgmii_phy_rxctl;                                

    /* BFM Tasks */

    task generate_clock(bit [1:0] mode);
        int period;        

        /* Determine the clock period based on the mode */
        case(mode) 
            2'b00: period = 4;     //Gbit - 8ns clock period
            2'b01: period = 20;     //100 mbps - 40ns clock period
            2'b10: period = 200;    //10mbps - 400ns clock period
            default : period = 4;
        endcase

        rgmii_phy_rxc <= 0;
        forever 
            #(period) rgmii_phy_rxc <= ~rgmii_phy_rxc; 
    
    endtask : generate_clock    

    task rgmii_drive_data(bit[7:0] rx_data[$], bit [1:0] link_speed, bit data_err, output bit bad_pckt);
        int data_not_valid = 1'b0;
        bad_pckt = 1'b0;
        
        while(rx_data.size() != 0) begin
            bit[7:0] data_byte = rx_data.pop_front();
            data_not_valid = $urandom_range(1, 1000);
            @(posedge rgmii_phy_rxc);
            rgmii_phy_rxd <= data_byte[3:0];
            //rgmii_phy_rxctl <= 1'b1;

            rgmii_phy_rxctl <= (data_err) ? (data_not_valid != 1) : 1'b1;
            if(data_err & data_not_valid == 1)
                bad_pckt = 1'b1;

            if(link_speed == 2'b00) begin
                @(negedge rgmii_phy_rxc);
            end else begin
                @(posedge rgmii_phy_rxc);            
            end

            rgmii_phy_rxd <= data_byte[7:4];
            rgmii_phy_rxctl <= 1'b1;
        end

        //Transmit interframe gap (12 bytes worth of data)
        repeat(24) begin
            @(posedge rgmii_phy_rxc);
            rgmii_phy_rxctl <= 1'b0;
            rgmii_phy_rxd <= 4'h0;
        end

    endtask : rgmii_drive_data    


endinterface