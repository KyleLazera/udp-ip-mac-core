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
    output wire [DATA_WIDTH-1:0] s_rx_axis_tdata,               //Data to transmit to asynch FIFO
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
reg [7:0] rgmii_rdx_0, rgmii_rdx_0_next;
reg [7:0] rgmii_rdx_1, rgmii_rdx_1_next;
reg [7:0] rgmii_rdx_2, rgmii_rdx_2_next;
reg [7:0] rgmii_rdx_3, rgmii_rdx_3_next;
reg [7:0] rgmii_rdx_4, rgmii_rdx_4_next;

/* Logic for shifting data into the registers from RGMII */
always @(posedge clk) begin
    //Synchronous active low reset
    if(~reset_n) begin
        rgmii_rdx_0 <= 8'b0;
        rgmii_rdx_1 <= 8'b0;
        rgmii_rdx_2 <= 8'b0;
        rgmii_rdx_3 <= 8'b0;
    end else begin
        rgmii_rdx_0 <= rgmii_rdx_0_next;
        rgmii_rdx_1 <= rgmii_rdx_1_next;
        rgmii_rdx_2 <= rgmii_rdx_2_next;
        rgmii_rdx_3 <= rgmii_rdx_3_next;        
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
