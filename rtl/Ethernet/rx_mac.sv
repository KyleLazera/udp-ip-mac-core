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
    input wire rgmii_mac_rx_er,                                 //Indicates an error in the data from the PHY
    input wire rgmii_mac_rx_rdy                                 //Used as a valid signal for the rx data
);

/* Local variables */
localparam [7:0] ETH_SFD = 8'hD5; 
localparam [7:0] ETH_HDR = 8'h55;

/* FSM Declarations */
typedef enum {IDLE,                                             //State that waits to detect a SFD
              PAYLOAD,                                          //State that is reading and transmitting the payload
              BAD_PCKT                                          //This state waits for teh reaminder of teh packet if there is an error
              } state_type;                   

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
reg [DATA_WIDTH-1:0] rgmii_rdx [4:0] = '{default: '0};
//Shift regiters to store data valid and error signals from rgmii
reg [4:0] rgmii_dv = 5'b0;
reg [4:0] rgmii_er = 5'b0;

/*Logic for shifting data & signals into shift registers from RGMII */
always @(posedge clk) begin
    if(rgmii_mac_rx_rdy) begin
        // Shifting Data Valid Signals 
        rgmii_dv[4] <= rgmii_dv[3];
        rgmii_dv[3] <= rgmii_dv[2];
        rgmii_dv[2] <= rgmii_dv[1];
        rgmii_dv[1] <= rgmii_dv[0];
        rgmii_dv[0] <= rgmii_mac_rx_dv;

        // Shifting Error Signals in 
        rgmii_er[4] <= rgmii_er[3];
        rgmii_er[3] <= rgmii_er[2];
        rgmii_er[2] <= rgmii_er[1];
        rgmii_er[1] <= rgmii_er[0];
        rgmii_er[0] <= rgmii_mac_rx_er;  

        // Shift in rx data
        rgmii_rdx[4] <= rgmii_rdx[3];
        rgmii_rdx[3] <= rgmii_rdx[2];
        rgmii_rdx[2] <= rgmii_rdx[1];                    
        rgmii_rdx[1] <= rgmii_rdx[0];
        rgmii_rdx[0] <= rgmii_mac_rx_data;        
    end
end

////////////////////////////////////////////////////////////////////////////////
// Block used to count the total number of header frames. This is important to make
// sure a transaction only starts upon the reception of a start condition:
// 7 bytes of 8'h55 and 1 start frame delimiter of 8'd5 along with the data valid signal
////////////////////////////////////////////////////////////////////////////////

reg [2:0] hdr_cnt = 4'b0;

always @(posedge clk) begin
    if(!reset_n)
        hdr_cnt <= 3'b0;
    else begin
        if(rgmii_mac_rx_rdy) begin
            if(rgmii_rdx[4] == ETH_HDR & rgmii_dv[4] == 1'b1)
                hdr_cnt <= hdr_cnt + 1;
            else
                hdr_cnt <= 3'b0;
        end
    end
end 

/* CRC Logic */

// CRC32 Module Instantiation 
crc32 #(.DATA_WIDTH(8)) 
crc_module(.i_byte(rgmii_rdx[4]),
           .i_crc_state(crc_state),
           .crc_en(crc_en),
           .o_crc_state(crc_next),
           .crc_out(crc_data_out)
           );       

always @(posedge clk) begin
    //Logic to update CRC State 
    if(crc_reset)
        crc_state <= 32'hFFFFFFFF;
    else if(crc_en)
        crc_state <= crc_next;
    else
        crc_state <= crc_state;
end

assign sof = ((rgmii_rdx[4] == ETH_SFD) && (hdr_cnt == 3'd7) && (rgmii_dv[4] && s_rx_axis_trdy));
assign crc_en = crc_en_reg;
assign crc_reset = (~reset_n || sof);

/* State Machine Logic */
always @(posedge clk) begin
    if(~reset_n) begin
        state_reg <= IDLE;
        axis_valid_reg <= 1'b0;
        axis_data_reg <= 1'b0;
        axis_last_reg <= 1'b0;
        axis_user_reg <= 1'b0;
        crc_en_reg <= 1'b0;        
    end else begin
            axis_valid_reg <= 1'b0;
            axis_last_reg <= 1'b0;
            crc_en_reg <= 1'b0;
            axis_user_reg <= 1'b0;

        if(rgmii_mac_rx_rdy) begin
            case(state_reg)
                IDLE: begin
                    //If data valid is high, SFD & HDR is found & FIFO is ready for data 
                    if(rgmii_rdx[4] == ETH_SFD && hdr_cnt == 3'd7 && rgmii_dv[4] && s_rx_axis_trdy) begin  
                        crc_en_reg <= 1'b1;
                        state_reg <= PAYLOAD;
                    end                  
                end
                PAYLOAD : begin
                    //If there is data to transmit, calculate crc and raise valid flag
                    axis_valid_reg <= 1'b1;
                    crc_en_reg <= 1'b1;

                    //Transmit the data from shift reg 4 to FIFO & CRC checker
                    axis_data_reg <= rgmii_rdx[4];

                    if((s_rx_axis_trdy == 1'b0) || !rgmii_dv[4] && rgmii_er[4]) begin //!rgmii_mac_rx_dv && rgmii_mac_rx_er || 
                        axis_user_reg <= 1'b1;
                        state_reg <= BAD_PCKT;
                    end

                    else if(!rgmii_mac_rx_dv && !rgmii_mac_rx_er) begin
                        axis_last_reg <= 1'b1;
                        crc_en_reg <= 1'b0;

                        if((crc_data_out != {rgmii_rdx[0], rgmii_rdx[1], rgmii_rdx[2], rgmii_rdx[3]}) && crc_en)
                            axis_user_reg <= 1'b1;

                        state_reg <= IDLE;
                    end                    
                end
                BAD_PCKT : begin
                    if(rgmii_mac_rx_dv == 1'b0)
                        state_reg <= IDLE;
                end
            endcase
        end
    end
end 

/* Output Logic */
assign m_rx_axis_tdata = axis_data_reg;
assign m_rx_axis_tuser = axis_user_reg;
assign m_rx_axis_tvalid = axis_valid_reg;
assign m_rx_axis_tlast = axis_last_reg;

endmodule
