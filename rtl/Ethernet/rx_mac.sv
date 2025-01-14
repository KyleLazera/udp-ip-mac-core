`timescale 1ns / 1ps

/*
 * Design Description:
 * Goal: Recieve and sample bytes of data that are transmitted by the RGMII at all possible clock frequencies (2.5/25/125MHz),
 *       and pass the data into an asnych FIFO for usage outside of the MAC. To do this, the module must be able to identify 
 *       the start of an ethernet packet (preamble and SFD), sample the payload, identify the final byte, and run CRC on payload
 *       to ensure there were no errors.
 *
 * Note: This module will be driven by the rxc clock recieved from the RGMII. This clock is buffered & delayed in the rgmii_phy_if 
 *      module, allowing it to be passed through the MAC. This means that the MAC will always sample data at the rate with which it
 *      is arriving from the RGMII, removing the concern of aliging and synchronizing the data with a different clock speed
 *      depending on the ethernet link bandwidth. 
 *
 * The Ethernet Frame for reference:
 * 
 *    7 Bytes     1 Byte   6 Bytes    6 Bytes     2 Bytes   46 - 1500 Bytes  Optional   4 Bytes  96-Bit Times
 *  ----------------------------------------------------------------------------------------------------
 *  |            |      |          |            |         |                |          |       |        |
 *  | Preamble   | SFD  | Dst Addr |  Src Addr  |  Length |    Payload     |  Padding |  CRC  |  IFG   |
 *  |            |      |          |            |         |                |          |       |        |
 *  ----------------------------------------------------------------------------------------------------
*/

/* TODO:
 * Driving the rx clk signal from the RGMII may require a BUFG vs a BUFR (Currently have BUFR)
 * Add support to the error and data valid signals 
 */

module rx_mac
#(
    parameter DATA_WIDTH = 8
)
(
    input wire clk,
    input wire reset_n,
    
    /* AXI Stream Output - FIFO */
    output wire [DATA_WIDTH-1:0] m_rx_axis_tdata,               //Data to transmit to asynch FIFO
    output wire m_rx_axis_tvalid,                               //Signal indicating module has data to transmit
    output wire m_rx_axis_tuser,                                //Used to indicate an error to the FIFO
    output wire m_rx_axis_tlast,                                //Indicates last byte within a packet
    
    /* FIFO Input/Control Signals */
    input wire s_rx_axis_trdy,                                  //FIFO indicating it is ready for data (not full/empty)
    
    /* RGMII Interface */
    input wire [DATA_WIDTH-1:0] rgmii_mac_rx_data,              //Input data from the RGMII PHY interface
    input wire rgmii_mac_rx_dv,                                 //Indicates data from PHY is valid
    input wire rgmii_mac_rx_er                                  //Indicates an error in the data from the PHY
);

/* Local variables */
localparam [7:0] ETH_SFD = 8'hD5; 
localparam [7:0] ETH_HDR = 8'h55;

/* FSM Declarations */
typedef enum {IDLE,                                             //State that waits to detect a SFD
              PAYLOAD,                                          //State that is reading and transmitting the payload
              BAD_PCKT                                          //This state waits for teh reaminder of teh packet if there is an error
              } state_type;
              
/* CRC32 Module Instantiation */
crc32 #(.DATA_WIDTH(8)) 
crc_module(.clk(clk),
           .i_byte(rgmii_rdx_4),
           .i_crc_state(crc_state),
           .crc_en(crc_en),
           .o_crc_state(crc_next),
           .crc_out(crc_data_out)
           );              

/* Signal/Register Declarations */
state_type state_reg, state_next;

//AXI Stream Signals/registers
reg axis_valid_reg, axis_valid_next;                            //FF that holds value of m_rx_axis_tvalid
reg axis_user_reg, axis_user_next;                              //Holds the value of the user signal to the FIFO
reg axis_last_reg, axis_last_next;                              //Holds the value of the m_rx_axis_tlast value
reg [DATA_WIDTH-1:0] axis_data_reg, axis_data_next;             //Holds the data to be transmitted out to the FIFO

//CRC Registers
reg [31:0] crc_state, crc_next;                                 //Holds the output state of the CRC32 module                                                                     
reg crc_en_reg, crc_en_next;                                    //Register that holds crc_en state 
reg sof;                                                        //Start of frame signal                              
wire crc_en, crc_reset;                                         //CRC enable & reset   
wire [31:0] crc_data_out;                                       //Ouput from the CRC32 module

//Shift registers to store incoming data from rgmii
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


/* Logic for shifting data & signals into shift registers from RGMII */
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
        rgmii_rdx_4 <= rgmii_rdx_3;
        rgmii_rdx_3 <= rgmii_rdx_2;
        rgmii_rdx_2 <= rgmii_rdx_1;                    
        rgmii_rdx_1 <= rgmii_rdx_0;
        rgmii_rdx_0 <= rgmii_mac_rx_data;
                           
        /* Shifting Data Valid Signals */
        rgmii_dv_4 <= rgmii_dv_3;
        rgmii_dv_3 <= rgmii_dv_2;
        rgmii_dv_2 <= rgmii_dv_1;
        rgmii_dv_1 <= rgmii_dv_0;
        rgmii_dv_0 <= rgmii_mac_rx_dv;

        /* Shifting Error Signals in */
        rgmii_er_4 <= rgmii_er_3;
        rgmii_er_3 <= rgmii_er_2;
        rgmii_er_2 <= rgmii_er_1;
        rgmii_er_1 <= rgmii_er_0;
        rgmii_er_0 <= rgmii_mac_rx_er;                                                 
    end      
end

/* State Machine & intermediry registers Sequential logic */
always @(posedge clk) begin
    if(~reset_n) begin
        state_reg <= IDLE;
        axis_valid_reg <= 1'b0;
        axis_data_reg <= 1'b0;
        axis_last_reg <= 1'b0;
        axis_user_reg <= 1'b0;
        crc_en_reg <= 1'b0;       
    end else begin
        state_reg <= state_next;
        axis_valid_reg <= axis_valid_next;
        axis_data_reg <= axis_data_next;
        axis_last_reg <= axis_last_next;
        axis_user_reg <= axis_user_next; 
        
        /* CRC Data Updates */
        crc_en_reg <= crc_en_next;       
        
        /* Logic to update CRC State */
        if(crc_reset)
            crc_state <= 32'hFFFFFFFF;
        else if(crc_en)
            crc_state <= crc_next;
        else
            crc_state <= crc_state;        
    end
end

/* Control Signals */
assign crc_en = crc_en_reg;
assign crc_reset = (~reset_n || sof);

/* Next State Logic */
always @(*) begin
    //Default Values
    state_next = state_reg;
    axis_valid_next = 1'b0;
    axis_data_next = axis_data_reg;
    axis_last_next = 1'b0;
    crc_en_next = 1'b0;
    axis_user_next = 1'b0;
    sof = 1'b0;
    
    case(state_reg) 
        IDLE : begin
            //If data valid is high, SFD & HDR is found & FIFO is ready for data  
            if(rgmii_rdx_4 == ETH_SFD && rgmii_dv_4 && s_rx_axis_trdy) begin
                sof = 1'b1;      
                crc_en_next = 1'b1;         
                state_next = PAYLOAD;
            end
        end
        PAYLOAD : begin  
           //If there is data to transmit, calculate crc and raise valid flag
           axis_valid_next = 1'b1;
           crc_en_next = 1'b1;
           
           //Transmit the data from shift reg 4 to FIFO & CRC checker
           axis_data_next = rgmii_rdx_4; 
           
           //If we have valid data, but there is an error, or if teh FIFO indicates it is not ready mid-transaction
           // raise tuser & do not sample remaining packet
           if(rgmii_dv_4 && rgmii_er_4 || (s_rx_axis_trdy == 1'b0)) begin
              axis_user_next = 1'b1; 
              state_next = BAD_PCKT;
           end                      
           //If we do not have valid data from RGMII - transmission complete
           else if(rgmii_mac_rx_dv == 1'b0) begin
               axis_last_next = 1'b1;  
           
               //If CRC is incorrect, raise tuser flag to indicate this error
               if(crc_data_out != {rgmii_rdx_0, rgmii_rdx_1, rgmii_rdx_2, rgmii_rdx_3})
                   axis_user_next = 1'b1;                    
                  
               state_next = IDLE;                                                    
           end
         
        end
        BAD_PCKT : begin
            //Wait for the data valid signal to go low indicating transaction from RGMII is complete
            if(rgmii_mac_rx_dv == 1'b0)
                state_next = IDLE;
        end
    endcase
    
end

/* Output Logic */
assign m_rx_axis_tdata = axis_data_reg;
assign m_rx_axis_tuser = axis_user_reg;
assign m_rx_axis_tvalid = axis_valid_reg;
assign m_rx_axis_tlast = axis_last_reg;

endmodule
