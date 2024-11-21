`ifndef _RX_MAC_IF
`define _RX_MAC_IF

interface rx_mac_if(input logic clk);
    /* LocalParams */
    localparam DATA_WIDTH = 8;
    
    /* Signals */
    logic reset_n;
    logic [DATA_WIDTH-1:0] m_rx_axis_tdata;             
    logic m_rx_axis_tvalid;                             
    logic m_rx_axis_tuser;                              
    logic m_rx_axis_tlast;                             
    logic s_rx_axis_trdy;                               
    logic [DATA_WIDTH-1:0] rgmii_mac_rx_data;           
    logic rgmii_mac_rx_dv;                              
    logic rgmii_mac_rx_er;
             
endinterface : rx_mac_if

`endif //_RX_MAC_IF