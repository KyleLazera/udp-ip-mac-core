`timescale 1ns/1ps

//Top level project that instantiates the ethernet MAC Core 

module ethernet_mac_project_top #(
    parameter RGMII_DATA_WIDTH = 4
)
(
    input wire i_clk,
    input wire i_reset_n,

    /* External RGMII Interface */
    input wire rgmii_phy_rxc,                                   //Recieved ethernet clock signal
    input wire [RGMII_DATA_WIDTH-1:0] rgmii_phy_rxd,            //Receieved data from PHY
    input wire rgmii_phy_rxctl,                                 //Control signal (dv ^ er) from PHY
    output wire rgmii_phy_txc,                                  //Outgoing data clock signal
    output wire [RGMII_DATA_WIDTH-1:0] rgmii_phy_txd,           //Outgoing ethernet packet data
    output wire rgmii_phy_txctl                                 //Outgoing control signal (dv ^ er)   
);

/****************************************************************
Reset Synchronization used for MMCM and IDELAYCTRL - These modules 
require active high, asynchronous resets
*****************************************************************/

wire async_reset;

reset_sync #(.ACTIVE_LOW(0)) async_reset_block(
    .i_clk(i_clk),
    .i_reset(~i_reset_n),
    .o_rst_sync(async_reset)
);

/****************************************************************
MMCM Instantiation:
- 100MHz System Clock and 125MHz Clock out
- Output clocks include 125MHz and 125MHz with a 90 degree phase shift
*****************************************************************/

wire mmcm_clk_feeback;
wire mmcm_clk_125;
wire mmcm_clk90_125;
wire mmcm_clk_200;
wire clk_200;
wire clk_125;
wire clk90_125;

MMCME2_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKOUT0_DIVIDE_F(8),
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(0),
    .CLKOUT1_DIVIDE(8),
    .CLKOUT1_DUTY_CYCLE(0.5),
    .CLKOUT1_PHASE(90),
    .CLKOUT2_DIVIDE(5),
    .CLKOUT2_DUTY_CYCLE(0.5),
    .CLKOUT2_PHASE(0),    
    .CLKFBOUT_MULT_F(10),
    .CLKFBOUT_PHASE(0),
    .DIVCLK_DIVIDE(1),
    .REF_JITTER1(0.010),
    .CLKIN1_PERIOD(10.0),
    .STARTUP_WAIT("FALSE"),
    .CLKOUT4_CASCADE("FALSE")
)
clk_mmcm_inst (
    .CLKIN1(i_clk),
    .CLKFBIN(mmcm_clk_feeback),
    .RST(async_reset), 
    .PWRDWN(1'b0),
    .CLKOUT0(mmcm_clk_125),
    .CLKOUT0B(),
    .CLKOUT1(mmcm_clk90_125),
    .CLKOUT1B(),
    .CLKOUT2(mmcm_clk_200),
    .CLKOUT2B(),
    .CLKOUT3(),
    .CLKOUT3B(),
    .CLKOUT4(),
    .CLKOUT5(),
    .CLKOUT6(),
    .CLKFBOUT(mmcm_clk_feeback),
    .CLKFBOUTB(),
    .LOCKED()
);

/****************************************************************
Buffer Instantiation Used to Drive newly generated clocks 
from MMCM by driving them through teh clock tree
*****************************************************************/

BUFG
clk_bufg_inst (
    .I(mmcm_clk_125),
    .O(clk_125)
);

BUFG
clk90_bufg_inst (
    .I(mmcm_clk90_125),
    .O(clk90_125)
);

BUFG
clk_200_bufg_inst (
    .I(mmcm_clk_200),
    .O(clk_200)
);

/****************************************************************
IDELAY Instantion - This is needed because the RGMII rx data arrives
in phase with the rx clock, therefore, there must be a 90 degree delay
to ensure timing is met correctly before the inputs are fed into the 
IDDR's
*****************************************************************/

wire [RGMII_DATA_WIDTH-1:0] rgmii_phy_delayed_rxd;            
wire rgmii_phy_delayed_rxctl; 
wire ictrl_rdy;

(* keep="true", IODELAY_GROUP = "rgmii_phy_idelay" *) // Specifies group name for associated IDELAYs/ODELAYs and IDELAYCTRL
IDELAYCTRL idelayctrl_inst(
    .REFCLK(clk_200),
    .RST(async_reset), 
    .RDY(ictrl_rdy)
);

(* IODELAY_GROUP = "rgmii_phy_idelay" *)
IDELAYE2 #(
    .IDELAY_TYPE("FIXED")
)
phy_rxd_idelay_0
(
    .IDATAIN(rgmii_phy_rxd[0]),
    .DATAOUT(rgmii_phy_delayed_rxd[0]),
    .DATAIN(1'b0),
    .C(1'b0),
    .CE(1'b0),
    .INC(1'b0),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(5'd0),
    .CNTVALUEOUT(),
    .LD(1'b0),
    .LDPIPEEN(1'b0),
    .REGRST(1'b0)
);

(* IODELAY_GROUP = "rgmii_phy_idelay" *)
IDELAYE2 #(
    .IDELAY_TYPE("FIXED")
)
phy_rxd_idelay_1
(
    .IDATAIN(rgmii_phy_rxd[1]),
    .DATAOUT(rgmii_phy_delayed_rxd[1]),
    .DATAIN(1'b0),
    .C(1'b0),
    .CE(1'b0),
    .INC(1'b0),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(5'd0),
    .CNTVALUEOUT(),
    .LD(1'b0),
    .LDPIPEEN(1'b0),
    .REGRST(1'b0)
);

(* IODELAY_GROUP = "rgmii_phy_idelay" *)
IDELAYE2 #(
    .IDELAY_TYPE("FIXED")
)
phy_rxd_idelay_2
(
    .IDATAIN(rgmii_phy_rxd[2]),
    .DATAOUT(rgmii_phy_delayed_rxd[2]),
    .DATAIN(1'b0),
    .C(1'b0),
    .CE(1'b0),
    .INC(1'b0),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(5'd0),
    .CNTVALUEOUT(),
    .LD(1'b0),
    .LDPIPEEN(1'b0),
    .REGRST(1'b0)
);

(* IODELAY_GROUP = "rgmii_phy_idelay" *)
IDELAYE2 #(
    .IDELAY_TYPE("FIXED")
)
phy_rxd_idelay_3
(
    .IDATAIN(rgmii_phy_rxd[3]),
    .DATAOUT(rgmii_phy_delayed_rxd[3]),
    .DATAIN(1'b0),
    .C(1'b0),
    .CE(1'b0),
    .INC(1'b0),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(5'd0),
    .CNTVALUEOUT(),
    .LD(1'b0),
    .LDPIPEEN(1'b0),
    .REGRST(1'b0)
);

(* IODELAY_GROUP = "rgmii_phy_idelay" *)
IDELAYE2 #(
    .IDELAY_TYPE("FIXED")
)
phy_rx_ctl_idelay
(
    .IDATAIN(rgmii_phy_rxctl),
    .DATAOUT(rgmii_phy_delayed_rxctl),
    .DATAIN(1'b0),
    .C(1'b0),
    .CE(1'b0),
    .INC(1'b0),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(5'd0),
    .CNTVALUEOUT(),
    .LD(1'b0),
    .LDPIPEEN(1'b0),
    .REGRST(1'b0)
);


/****************************************************************
Ethernet MAC Instantiation :
For the specific case of testing, the rx axi fifo signals are looped
into the tx axi fifo signals. This is for a simple echo test, to see
if teh ethernet MAC can echo the data it recieves.
*****************************************************************/

wire data_feedback_rdy;
wire data_feedback_payload;
wire data_feedback_last;
wire data_feedback_tx_rdy;


ethernet_mac_fifo ethernet_mac(
    .i_clk(i_clk),
    .clk_125(clk_125),
    .clk90_125(clk90_125),
    .i_reset_n(i_reset_n),

    /* External RGMII interface */
    .rgmii_phy_rxc(rgmii_phy_rxc),                                  
    .rgmii_phy_rxd(rgmii_phy_delayed_rxd),           
    .rgmii_phy_rxctl(rgmii_phy_delayed_rxctl),                                
    .rgmii_phy_txc(rgmii_phy_txc),                                 
    .rgmii_phy_txd(rgmii_phy_txd),           
    .rgmii_phy_txctl(rgmii_phy_txctl),

    /* TX FIFO AXI Interface */
    .s_tx_axis_tdata(data_feedback_payload),            
    .s_tx_axis_tvalid(data_feedback_rdy),                                
    .s_tx_axis_tlast(data_feedback_last),                                
    .m_tx_axis_trdy(data_feedback_tx_rdy),                                 

    /* Rx FIFO - AXI Interface*/
    .m_rx_axis_tdata(data_feedback_payload),           
    .m_rx_axis_tvalid(data_feedback_rdy),                                
    .m_rx_axis_tlast(data_feedback_last),                                
    .s_rx_axis_trdy(data_feedback_tx_rdy)                                              
);


endmodule