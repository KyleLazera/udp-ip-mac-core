`timescale 1ns / 1ps

/*
 * The Ethernet Frame for reference:
 * 
 *    7 Bytes     1 Byte   6 Bytes    6 Bytes     2 Bytes   46 - 1500 Bytes  Optional   4 Bytes  96-Bit Times
 *  ----------------------------------------------------------------------------------------------------
 *  |            |      |          |            |         |                |          |       |        |
 *  | Preamble   | SFD  | Dst Addr |  Src Addr  |  Length |    Payload     |  Padding |  CRC  |  IFG   |
 *  |            |      |          |            |         |                |          |       |        |
 *  ----------------------------------------------------------------------------------------------------
*/

module rx_mac
#(
    parameter DATA_WIDTH = 8,
    parameter IFG_SIZE = 12
)
(
    input wire clk,
    input wire reset_n,
    
    /* AXI Stream Output - FIFO */
    output wire [DATA_WIDTH-1:0] m_rx_axis_tdata,               //Data to transmit to asynch FIFO
    output wire m_rx_axis_tvalid,                               //Signal indicating module has data to transmit
    output wire m_rx_axis_tlast,                                //Indicates last byte within a packet
    
    /* FIFO Input/Control Signals */
    input wire s_rx_axis_trdy,                                  //FIFO indicating it is ready for data (not full/empty)
    
    /* RGMII Interface */
    input wire [DATA_WIDTH-1:0] rgmii_mac_rx_data,              //Input data from the RGMII PHY interface
    input wire rgmii_mac_rx_dv,                                 //Indicates data from PHY is valid
    input wire rgmii_mac_rx_er,                                 //Indicates an error in the data from the PHY
    
    /* Control Signals */
    input wire mii_select                                       //Indicates whether the data is coming in at SDR or DDR 
);

//FSM Declarations 
typedef enum {IDLE,                                             //State that waits to detect a SFD
              PAYLOAD                                           //State that is reading and transmitting the payload
              } state_type;

/* Signal/Register Declarations */
state_type state_reg, state_next;

//5 Shift registers to store incoming data from rgmii
reg [DATA_WIDTH-1:0] rgmii_rdx_0;
reg [DATA_WIDTH-1:0] rgmii_rdx_1;
reg [DATA_WIDTH-1:0] rgmii_rdx_2;
reg [DATA_WIDTH-1:0] rgmii_rdx_3;
reg [DATA_WIDTH-1:0] rgmii_rdx_4;
//Shift regiters to store data valid and error signals from rgmii
reg [DATA_WIDTH-1:0] rgmii_dv_0, rgmii_er_0;
reg [DATA_WIDTH-1:0] rgmii_dv_1, rgmii_er_1;
reg [DATA_WIDTH-1:0] rgmii_dv_2, rgmii_er_2;
reg [DATA_WIDTH-1:0] rgmii_dv_3, rgmii_er_3;
reg [DATA_WIDTH-1:0] rgmii_dv_4, rgmii_er_4;

/* Logic for shifting data & signals into the registers from RGMII */
always @(posedge clk) begin
    //Synchronous active low reset
    if(~reset_n) begin
        /* Reset Logic for data shift registers */
        rgmii_rdx_0 <= 8'b0;
        rgmii_rdx_1 <= 8'b0;
        rgmii_rdx_2 <= 8'b0;
        rgmii_rdx_3 <= 8'b0;
        rgmii_rdx_4 <= 8'b0;
        
        /* Reset Logic for data valid flag shift registers */
        rgmii_dv_0 <= 8'b0;
        rgmii_dv_1 <= 8'b0;
        rgmii_dv_2 <= 8'b0;
        rgmii_dv_3 <= 8'b0;
        rgmii_dv_4 <= 8'b0; 
        
        /* Reset Logic for data error shift registers */
        rgmii_er_0 <= 8'b0;
        rgmii_er_1 <= 8'b0;
        rgmii_er_2 <= 8'b0;
        rgmii_er_3 <= 8'b0;
        rgmii_er_4 <= 8'b0;           
        
    end else begin
        /* Shifting Data bytes in */
        rgmii_rdx_0 <= rgmii_mac_rx_data;
        rgmii_rdx_1 <= rgmii_rdx_0;
        rgmii_rdx_2 <= rgmii_rdx_1;
        rgmii_rdx_3 <= rgmii_rdx_2;
        rgmii_rdx_4 <= rgmii_rdx_3; 
        
        /* Shifting Data Valid Signals */
        rgmii_dv_0 <= rgmii_mac_rx_dv;
        rgmii_dv_1 <= rgmii_dv_0;
        rgmii_dv_2 <= rgmii_dv_1;
        rgmii_dv_3 <= rgmii_dv_2;
        rgmii_dv_4 <= rgmii_dv_3; 
        
        /* Shifting Error Signals in */
        rgmii_er_0 <= rgmii_mac_rx_er;
        rgmii_er_1 <= rgmii_er_0;
        rgmii_er_2 <= rgmii_er_1;
        rgmii_er_3 <= rgmii_er_2;
        rgmii_er_4 <= rgmii_er_3;                       
    end 
end

/* State Machine Sequential logic */
always @(posedge clk) begin
    if(~reset_n)
        state_reg <= IDLE;
    else
        state_reg <= state_next;
end


endmodule
