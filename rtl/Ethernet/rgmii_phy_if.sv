`timescale 1ns / 1ps

/* 
 * This RGMII interface was written for the Nexys Video Dev board which has an RTL8211E (Realtek) PHY. The PHY
 * contains an RGMII interface and supports 10/100/1000 Mpbs ethernet transactions. This PHY interface supports
 * 10/100/1000 Mbps link speeds for the txc and utilizes the input speed signal to determine what the output link
 * speed should be. This module is also responsible for buffering the input and output signals and to generate the tx 
 * clock signal with the correct clock skew.
 * This also transmits data out most significant bit first, which is based on the ethernet rgmii standard.
*/

/*
 * todo: Add logic to sample 10/100 mbps using IDDR flip flops
*/

module rgmii_phy_if
(
    input wire clk_125,                       //125MHz MAC Domain Clock 
    input wire clk90_125,                     //125MHz clock with a 90 degree phase shift (Used for TXC)
    input wire reset_n,                       //Active low reset signal
    
    /* PHY Interface */
    input wire rgmii_phy_rxc,                 //recieved clock from the PHY
    input wire [3:0] rgmii_phy_rxd,           //recieve data line from PHY
    input wire rgmii_phy_rxctl,               //recoeve control siganl from PHY
    output wire rgmii_phy_txc,                //clock that drives txdata to PHY
    output wire [3:0] rgmii_phy_txd,          //tx data driven to PHY
    output wire rgmii_phy_txctl,              //tx control signal driven to PHY
    
    /* MAC Interface */
    input wire [7:0] rgmii_mac_tx_data,       //tx data to transmit to the PHY
    input wire rgmii_mac_tx_dv,               //tx data valid signal - indicates to the PHY that the data is valid and it can be transmitted       
    input wire rgmii_mac_tx_er,               //tx data error - Indicates an error in the data
    output wire rgmii_mac_tx_rdy,             //Signal to indicate new data can be driven from MAC
    output wire rgmii_mac_rx_clk,             //RX PHY clock
    output reg [7:0] rgmii_mac_rx_data,       //Data recieved from PHY
    output wire rgmii_mac_rx_dv,              //RX data valid signal - driven on the posedge of the rxctl signal
    output wire rgmii_mac_rx_er,              //RX error signal - falling edge of rxc drives error XOR data_valid
    output wire rgmii_mac_rx_rdy,             //This is used for SDR to ensure the rx mac is taking in teh correct data
   
   /* Control Signal(s) */
    input wire [1:0] link_speed               //Indicates the speed of the rxc (used to dictate speed of txc) 
);

/*** PHY RX (Data reception) ***/

wire rgmii_rx_dv, rgmii_rx_er;
reg [3:0] rgmii_rxd_rising_edge;
reg [3:0] rgmii_rxd_falling_edge;
reg [3:0] rxd_lower_nibble = 3'b0;
reg [3:0] rx_dv, rx_er;
reg [1:0] rxc_cntr;                 //Used to count the number of rxc positive edge - this is needed for single data rate

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Counts the number of clock edges from the rgmii receieved clock. This is important for 10/100mbps 
// where data transmission occurs at single data rate. For single data rate, we sample a nibble of data
// on each clock edge. The first clock edge sends the upper data nibble (most significant bits) and the second 
// rising edge sends the lower nibble (least significant bits). Therefore, for each transaction in SDR mode, 
// we need to know when 2 clock edge have occured to create out byte of data.
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge rgmii_mac_rx_clk) begin
    if(!reset_n)
        rxc_cntr <= 2'b00;
    else begin
        rxc_cntr <= (rxc_cntr == 2'b10) ? 2'b01 : rxc_cntr + 1;
    end
end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Logic to drive the correct data depending on the link speed/throughput - when throughput is 10/100mbps, 
// we cannot use the IDDR output data because the RGMII will recieve a new nibble of data on each rising
// edge as opposed to each rising and falling edge. 
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge rgmii_mac_rx_clk) begin
    if(link_speed == 2'b10) begin
        rgmii_mac_rx_data <= {rgmii_rxd_falling_edge, rgmii_rxd_rising_edge};
        rx_dv <= rgmii_rx_dv;
        rx_er <= rgmii_rx_er;
    end else begin

        if(rxc_cntr == 2'b01) 
            rxd_lower_nibble <= rgmii_rxd_rising_edge;
    
        if(rxc_cntr == 2'b10) begin
            rgmii_mac_rx_data <= {rgmii_rxd_rising_edge, rxd_lower_nibble};
            rx_dv <= rgmii_rx_dv;
            rx_er <= rgmii_rx_er;        
        end    
    end
end

//Input buffers for the PHY signals through IDDR
input_buffers #(.DATA_WIDTH(5)) 
i_buff(.clk(rgmii_phy_rxc),
       .d_in({rgmii_phy_rxd, rgmii_phy_rxctl}),         //Input signals from PHY
       .o_clk(rgmii_mac_rx_clk),                        //Output clock for MAC - passed through BUFR   
       .q1({rgmii_rxd_rising_edge, rgmii_rx_dv}),      //Rising edge data
       .q2({rgmii_rxd_falling_edge, rgmii_rx_er}));     //Falling edge data        

//The rxctl signal provides 2 values: on rising edge, it provides data valid and on falling edge 
//it produces the XOR with dava valid and error flag - this is from the RGMII standard
assign rgmii_mac_rx_dv = rx_dv;
assign rgmii_mac_rx_er = rx_er ^ rx_dv;
assign rgmii_mac_rx_rdy = (link_speed == 2'b10) ? 1'b1 : (rxc_cntr == 2'b10); 

/*** PHY TX (Data Transmission) ***/

// Registers/Signal Declarations
reg rgmii_tx_data_rdy;
reg rgmii_txc_1, rgmii_txc_2;
reg [3:0] rgmii_txd_1, rgmii_txd_2;
reg rgmii_txctl_1, rgmii_txctl_2;
reg [5:0] counter_reg;
wire rgmii_tx_clk;

//Logic to determine the tx clock for the PHY 
always @(posedge clk_125) begin
    //Active low synchronous reset
    if(~reset_n) begin
        //By setting txc_1 and txc_2 to 1 & 0 respectivley, default output would be 125MHz
        rgmii_txc_1 <= 1'b1;
        rgmii_txc_2 <= 1'b0;
        counter_reg <= 1'b0;
        rgmii_tx_data_rdy <= 1'b1;
    end else begin
        //Default value to avoid inferred latch (no need for else statement)
        rgmii_txc_1 <= rgmii_txc_2;
    
        //10Mbps - clock speed of 2.5MHz
        if(link_speed == 2'b00) begin
            counter_reg <= counter_reg + 1;
            rgmii_tx_data_rdy <= 1'b0;
            //If 200ns has passed - rising edge of clock (2.5MHz - 400ns period)
            if(counter_reg == 6'd24) begin
                rgmii_txc_1 <= 1'b1;
                rgmii_txc_2 <= 1'b1;
            end
            //If 400ns has passed reset the signals 
            else if(counter_reg >= 6'd49) begin
                rgmii_txc_1 <= 1'b0;
                rgmii_txc_2 <= 1'b0;
                rgmii_tx_data_rdy <= 1'b1;  
                counter_reg <= 6'b0;          
            end         
        end 
        //100Mbps - clock speed of 25MHz 
        else if(link_speed == 2'b01) begin
            counter_reg <= counter_reg + 1;
            rgmii_tx_data_rdy <= 1'b0;
            
            if(counter_reg == 6'd0) begin
                rgmii_txc_1 <= 1'b0;
                rgmii_txc_2 <= 1'b0;
            end 
            //If half period has passed raise the clock
            else if(counter_reg == 6'd2) begin
                rgmii_txc_1 <= 1'b1;
                rgmii_txc_2 <= 1'b1;
            end          
            //After full period, falling edge
            else if(counter_reg >= 6'd4) begin
                rgmii_txc_1 <= 1'b1;
                rgmii_txc_2 <= 1'b0; 
                rgmii_tx_data_rdy <= 1'b1;   
                counter_reg <= 6'b0;    
            end 
    
        end
        //1000Mbps - Clock speed of 125MHz
        else if(link_speed == 2'b10) begin
            rgmii_txc_1 <= 1'b1;
            rgmii_txc_2 <= 1'b0; 
            rgmii_tx_data_rdy <= 1'b1;       
        end
    end
end

//Combinational logic to determine the tx data output signals and tx ctrl signals
//based on the link speed
always @(*) begin
    //10Mbps & 100Mbps - Transmit at Single Data Rate (SDR)
    if(link_speed == 2'b00 || link_speed == 2'b01) begin
        rgmii_txd_1 = rgmii_mac_tx_data[3:0];
        rgmii_txd_2 = rgmii_mac_tx_data[3:0];
        //On teh falling edge of the tx clock drive the XOR of datavalid and error
        if(rgmii_txc_1) begin
            rgmii_txctl_1 = rgmii_mac_tx_dv ^ rgmii_mac_tx_er;
            rgmii_txctl_2 = rgmii_mac_tx_dv ^ rgmii_mac_tx_er;
        //On rising edge of tx clk drive the data valid signal
        end else begin
            rgmii_txctl_1 = rgmii_mac_tx_dv;
            rgmii_txctl_2 = rgmii_mac_tx_dv;            
        end
    end 
    //1000Mbps/1Gbps - Transmit at Double Data Rate (DDR)
    else begin
        rgmii_txd_1 = rgmii_mac_tx_data[3:0];
        rgmii_txd_2 = rgmii_mac_tx_data[7:4];
        rgmii_txctl_1 = rgmii_mac_tx_dv;
        rgmii_txctl_2 = rgmii_mac_tx_dv ^ rgmii_mac_tx_er;
    end
end 

//Pass the output signals through an ODDR primitive to be passed to PHY:
//Tx Clock signal 
output_buffers#(.DATA_WIDTH(1))
clk_oddr(.clk(clk90_125),
         .d_in_1(rgmii_txc_1),
         .d_in_2(rgmii_txc_2),
         .d_out(rgmii_tx_clk)
         );
         
//Data and Control Signals
output_buffers#(.DATA_WIDTH(5))
data_oddr(.clk(clk_125),
          .d_in_1({rgmii_txd_1, rgmii_txctl_1}),
          .d_in_2({rgmii_txd_2, rgmii_txctl_2}),
          .d_out({rgmii_phy_txd, rgmii_phy_txctl})
          );         

assign rgmii_mac_tx_rdy = rgmii_tx_data_rdy;
assign rgmii_phy_txc = rgmii_tx_clk;

endmodule
