`timescale 1ns/1ps

module ethernet_mac_project_top #(
    parameter RGMII_DATA_WIDTH = 4
)
(
    input wire i_clk,
    input wire i_reset_n,

    /* Testing status */
    output wire o_reset_status,

    /* External RGMII Interface */
    input wire rgmii_phy_rxc,                                   //Recieved ethernet clock signal
    input wire [RGMII_DATA_WIDTH-1:0] rgmii_phy_rxd,            //Receieved data from PHY
    input wire rgmii_phy_rxctl,                                 //Control signal (dv ^ er) from PHY
    output wire rgmii_phy_txc,                                  //Outgoing data clock signal
    output wire [RGMII_DATA_WIDTH-1:0] rgmii_phy_txd,           //Outgoing ethernet packet data
    output wire rgmii_phy_txctl,                                //Outgoing control signal (dv ^ er)   
    output wire rgmii_phy_rstb                                  //Active low PHY reset
);

/* Constants */
localparam SRC_MAC = 48'hDEADBEEF000A;
localparam SRC_IP = 32'h10_00_00_00;
localparam ETH_TYPE = 16'h0800;
localparam IP_PROTOCL = 8'h11;

assign o_reset_status = i_reset_n;
assign rgmii_phy_rstb = i_reset_n;

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

/* RX AXI Signals from Ethernet MAC */
reg [7:0] rx_axis_eth_tdata;
reg rx_axis_eth_tvalid;
reg rx_axis_eth_tlast;
reg rx_axis_eth_trdy;

reg rx_ip_hdr_trdy;
reg rx_ip_hdr_tvalid;
reg [15:0] rx_ip_total_length;
reg [31:0] rx_src_ip_addr;
reg [31:0] rx_dst_ip_addr;
reg [47:0] rx_src_mac_addr;
reg [47:0] rx_dst_mac_addr;
reg [15:0] rx_eth_type;

reg rx_udp_hdr_rdy;
reg rx_udp_hdr_tvalid;
reg [15:0] rx_dst_port;
reg [15:0] rx_src_port;
reg [15:0] rx_udp_length;
reg [15:0] rx_udp_checksum;

reg [7:0] rx_axis_ip_tdata;
reg rx_axis_ip_tvalid;
reg rx_axis_ip_tlast;
reg rx_axis_ip_trdy;

reg [7:0] rx_axis_udp_tdata;
reg rx_axis_udp_tvalid;
reg rx_axis_udp_tlast;
reg rx_axis_udp_trdy;

/* TX AXI Signals from IP Stack */
reg [7:0] tx_axis_eth_tdata;
reg tx_axis_eth_tvalid;
reg tx_axis_eth_tlast;
reg tx_axis_eth_trdy;

reg tx_ip_hdr_trdy;
reg tx_ip_hdr_tvalid;
reg [15:0] tx_ip_total_length;
reg [31:0] tx_src_ip_addr;
reg [31:0] tx_dst_ip_addr;
reg [47:0] tx_src_mac_addr;
reg [47:0] tx_dst_mac_addr;
reg [15:0] tx_eth_type;

reg tx_udp_hdr_rdy;
reg tx_udp_hdr_tvalid;
reg [15:0] tx_src_port;
reg [15:0] tx_dst_port;

reg [7:0] tx_axis_ip_tdata;
reg tx_axis_ip_tvalid;
reg tx_axis_ip_tlast;
reg tx_axis_ip_trdy;

reg [7:0] tx_axis_udp_tdata;
reg tx_axis_udp_tvalid;
reg tx_axis_udp_tlast;
reg tx_axis_udp_trdy;

wire ip_hdr_valid;
wire udp_hdr_valid;
wire [15:0] ip_checksum;
wire [15:0] ip_length;
wire [15:0] udp_length;
wire [15:0] udp_checksum;

// Loop Back Logic for Payload
assign tx_axis_udp_tdata = rx_axis_udp_tdata;
assign tx_axis_udp_tvalid = rx_axis_udp_tvalid;
assign tx_axis_udp_tlast = rx_axis_udp_tlast;
assign rx_axis_udp_trdy = tx_axis_udp_trdy;

// Header Data Loop back
always @(posedge clk_200) begin
    tx_ip_hdr_tvalid <= rx_ip_hdr_tvalid;
    rx_ip_hdr_trdy <= tx_ip_hdr_trdy;
    tx_ip_total_length <= rx_ip_total_length;
    tx_src_ip_addr <= SRC_IP;
    tx_dst_port <= rx_src_port;
    tx_src_port <= rx_dst_port;
    tx_dst_ip_addr <= rx_src_ip_addr;
    tx_src_mac_addr <= SRC_MAC;
    tx_dst_mac_addr <= rx_src_mac_addr;
    tx_eth_type <= ETH_TYPE;
    tx_udp_hdr_tvalid <= rx_udp_hdr_tvalid;
    rx_udp_hdr_rdy <= tx_udp_hdr_rdy;
end


/******** UDP Stack Instantiation ********/

udp#(.AXI_DATA_WIDTH(8),
     .MAX_PAYLOAD(1472)
) udp_stack (

    .i_clk(clk_200),
    .i_reset_n(i_reset_n),
    
    /*********** TX Data Path ***********/

    // UDP Field Inputs
    .s_udp_tx_hdr_trdy(tx_udp_hdr_rdy),
    .s_udp_tx_hdr_tvalid(tx_udp_hdr_tvalid),
    .s_udp_tx_src_port(tx_src_port),
    .s_udp_tx_dst_port(tx_dst_port),

    //IP Field Inputs
    .s_ip_tx_src_ip_addr(tx_src_ip_addr),                               
    .s_ip_tx_dst_ip_addr(tx_dst_ip_addr), 
    .s_ip_tx_protocol(IP_PROTOCL),  

    // AXI-Stream Payload
    .s_tx_axis_tdata(tx_axis_udp_tdata),
    .s_tx_axis_tvalid(tx_axis_udp_tvalid),
    .s_tx_axis_tlast(tx_axis_udp_tlast),
    .s_tx_axis_trdy(tx_axis_udp_trdy),

    // TX Data Path Output
    .m_udp_tx_hdr_valid(udp_hdr_valid),
    .m_udp_tx_length(udp_length),
    .m_udp_tx_checksum(udp_checksum),

    // UDP Packet Output
    .m_tx_axis_tdata(tx_axis_ip_tdata),
    .m_tx_axis_tvalid(tx_axis_ip_tvalid),
    .m_tx_axis_tlast(tx_axis_ip_tlast),
    .m_tx_axis_trdy(tx_axis_ip_trdy),

    /*********** RX Data Path ***********/
    
    .s_rx_axis_tdata(rx_axis_ip_tdata),
    .s_rx_axis_tvalid(rx_axis_ip_tvalid),
    .s_rx_axis_tlast(rx_axis_ip_tlast),
    .s_rx_axis_trdy(rx_axis_ip_trdy),

    .m_rx_axis_tdata(rx_axis_udp_tdata),
    .m_rx_axis_tvalid(rx_axis_udp_tvalid),
    .m_rx_axis_tlast(rx_axis_udp_tlast),
    .m_rx_axis_trdy(rx_axis_udp_trdy),

    .s_udp_rx_hdr_trdy(rx_udp_hdr_rdy),
    .s_udp_rx_hdr_tvalid(rx_udp_hdr_tvalid),
    .s_udp_rx_src_port(rx_src_port),
    .s_udp_rx_dst_port(rx_dst_port),
    .s_udp_rx_length_port(rx_udp_length),
    .s_udp_rx_hdr_checksum(rx_udp_checksum)
);



/******** IP Stack Instantiation ********/

ip #(.AXI_STREAM_WIDTH(8), 
     .ETH_FRAME(1)
) ip_stack (
    .i_clk                  (clk_200),
    .i_reset_n              (i_reset_n),

    /****************** TX Data Path ******************/

    // TX To Ethernet MAC - IP Payload Input
    .s_ip_tx_hdr_valid      (tx_udp_hdr_tvalid),
    .s_ip_tx_hdr_rdy        (tx_ip_hdr_trdy),
    .s_ip_tx_hdr_type       (8'h00),
    .s_ip_tx_protocol       (IP_PROTOCL), 
    .s_ip_tx_src_ip_addr    (tx_src_ip_addr),
    .s_ip_tx_dst_ip_addr    (tx_dst_ip_addr),
    .s_eth_tx_src_mac_addr  (tx_src_mac_addr),
    .s_eth_tx_dst_mac_addr  (tx_dst_mac_addr),
    .s_eth_tx_type          (tx_eth_type),

    // AXI Stream Payload Inputs
    .s_tx_axis_tdata        (tx_axis_ip_tdata),
    .s_tx_axis_tvalid       (tx_axis_ip_tvalid),
    .s_tx_axis_tlast        (tx_axis_ip_tlast),
    .s_tx_axis_trdy         (tx_axis_ip_trdy),

    // Not Used because ETH_FRAME = 1
    .m_eth_hdr_trdy         (),
    .m_eth_hdr_tvalid       (),
    .m_eth_src_mac_addr     (),
    .m_eth_dst_mac_addr     (),
    .m_eth_type             (),

    // Tx Ethernet Frame Output
    .m_tx_axis_tdata        (tx_axis_eth_tdata),
    .m_tx_axis_tvalid       (tx_axis_eth_tvalid),
    .m_tx_axis_tlast        (tx_axis_eth_tlast),
    .m_tx_axis_trdy         (tx_axis_eth_trdy),

    // IP Header fields computed in parallel 
    .m_ip_tx_hdr_tvalid     (ip_hdr_valid),                                     
    .m_ip_tx_total_length   (ip_length),
    .m_ip_tx_checksum       (ip_checksum),

    /****************** RX Data Path ******************/

    /* Not Used due to ETH_FRAME = 1 */
    .s_eth_hdr_valid        (),
    .s_eth_hdr_rdy          (),
    .s_eth_rx_src_mac_addr  (),
    .s_eth_rx_dst_mac_addr  (),
    .s_eth_rx_type          (),

    // Ethernet Frame Input
    .s_rx_axis_tdata        (rx_axis_eth_tdata),
    .s_rx_axis_tvalid       (rx_axis_eth_tvalid),
    .s_rx_axis_tlast        (rx_axis_eth_tlast),
    .s_rx_axis_trdy         (rx_axis_eth_trdy),

    // De-encapsulated Frame Output
    .m_ip_hdr_trdy          (rx_udp_hdr_rdy),
    .m_ip_hdr_tvalid        (rx_ip_hdr_tvalid),
    .m_ip_rx_src_ip_addr    (rx_src_ip_addr),
    .m_ip_rx_dst_ip_addr    (rx_dst_ip_addr),
    .m_eth_rx_src_mac_addr  (rx_src_mac_addr),
    .m_eth_rx_dst_mac_addr  (rx_dst_mac_addr),
    .m_eth_rx_type          (rx_eth_type),

    // IP Frame Payload
    .m_rx_axis_tdata        (rx_axis_ip_tdata),
    .m_rx_axis_tvalid       (rx_axis_ip_tvalid),
    .m_rx_axis_tlast        (rx_axis_ip_tlast),
    .m_rx_axis_trdy         (rx_axis_ip_trdy),

    // Status Flags
    .bad_packet             ()
);


/******** Ethernet MAC Instantiation ********/


ethernet_mac_fifo #(
    .UDP_HEADER_INSERTION(1),
    .IP_HEADER_INSERTION(1)
) ethernet_mac (
    .i_clk(clk_200),
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
    .s_tx_axis_tdata(tx_axis_eth_tdata),             
    .s_tx_axis_tvalid(tx_axis_eth_tvalid),                                 
    .s_tx_axis_tlast(tx_axis_eth_tlast),                         
    .m_tx_axis_trdy(tx_axis_eth_trdy),    

    /* IP & UDP Header fields - Used for Late Insertion */
    .s_hdr_tvalid(ip_hdr_valid & udp_hdr_valid),                                    
    .s_udp_hdr_length(udp_length),                        
    .s_udp_hdr_checksum(udp_checksum),                       
    .s_ip_hdr_length(ip_length),                          
    .s_ip_hdr_checksum(ip_checksum),                                                  

    /* Rx FIFO - AXI Interface*/
    .m_rx_axis_tdata(rx_axis_eth_tdata),           
    .m_rx_axis_tvalid(rx_axis_eth_tvalid),                                
    .m_rx_axis_tlast(rx_axis_eth_tlast),                                
    .s_rx_axis_trdy(rx_axis_eth_trdy)                                              
);


endmodule