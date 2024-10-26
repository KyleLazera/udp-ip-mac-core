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

/*
 * TODO: 
 * 1) Handle the rgmii_mac_tx_er signals
 * 2) IFG length for different link throughputs (10/100/1000 Mbps)
*/

module tx_mac
#(
    parameter DATA_WIDTH = 8,
    parameter IFG_SIZE = 12
) 
(
    input wire clk, 
    input wire reset_n,
    
    /* AXI Stream Input - FIFO */
    input wire [DATA_WIDTH-1:0] s_tx_axis_tdata,            //Incoming bytes of data from the FIFO    
    input wire s_tx_axis_tvalid,                            //Indicates FIFO has valid data (is not empty)
    input wire s_tx_axis_tlast,                             //Indicates last beat of transaction (final byte in packet)
    input wire s_tx_axis_tkeep,                             //TODO: Determine if will be used
    input wire s_tx_axis_tuser,                             //TODO: Determine if will be used
    
    /* AXI Stream Output - FIFO */
    output wire s_tx_axis_trdy,                             //Indicates to FIFO that it can read data (used to set rd_en for FIFIO)
    
    /* RGMII Interface */
    input wire rgmii_mac_tx_rdy,                            //Indicates the RGMII inteface is ready for data 
    output wire [DATA_WIDTH-1:0] rgmii_mac_tx_data,         //Bytes to be transmitted to the RGMII
    output wire rgmii_mac_tx_dv,                            //Indicates the data is valid 
    output wire rgmii_mac_tx_er,                            //Indicates there is an error in the data
    
    /* Configurations */
    input wire mii_select                                   //Configures data rate (Double Data Rate (DDR) or Singale Data Rate (SDR))        
);

/* Local Parameters */
localparam [7:0] ETH_HDR = 8'h55;               
localparam [7:0] ETH_SFD = 8'hD5;  
localparam [7:0] ETH_PAD = 8'h00;    
localparam MIN_FRAME_WIDTH = 59;                            //46 byte minimum Payload + 12 Address Bytes + 2 Type/Length Bytes = 60 bytes         

/* FSM State Declarations */
typedef enum{IDLE,              //State when no transactions are occuring
             PREAMBLE,          //Transmit the ethernet preamble & SFD
             PACKET,            //Transmit the payload receieved from the FIFO
             PADDING,           //Add padding to the payload if it did not meet minimum requirements
             FCS,               //Append the Frame Check Sequence
             IFG                //Add an Inter Frame Gap
             } state_type; 


/* Signal Declarations */
state_type state_reg, state_next;                               //Holds the current and next State 
reg [DATA_WIDTH-1:0] tx_data_reg, tx_data_next;                 //Holds data to be transmitted to RGMII
reg rgmii_dv_reg, rgmii_dv_next;                                //Data Valid signal for the RGMII
reg rgmii_er_reg, rgmii_er_next;                                //Error Signal for teh RGMII
reg [2:0] byte_ctr, byte_ctr_next;                              //Counts the number of bytes transmitted
reg [7:0] pckt_size, pckt_size_next;                            //Counts size of payload in bytes (Ensure they payload is between 46 - 1500 bytes) 
reg mii_sdr, mii_sdr_next;                                      //Indicates the next data transfer needs to shift byte by 4 (for SDR in MII mode)
reg axis_rdy_reg, axis_rdy_next;                                //Implements a FF between the outgoing s_tx_axis_rdy signal and FIFO  
reg [3:0] ifg_ctr, ifg_ctr_next;


/* CRC32 Interface Signals */
reg [31:0] crc_state, crc_next;                                 //Holds the output state of the CRC32 module                                       
reg [DATA_WIDTH-1:0] crc_in_data_reg, crc_in_data_next;         //Holds the input values for the CRC32 module                               
reg crc_en_reg, crc_en_next;                                    //Register that holds crc_en state 
wire [DATA_WIDTH-1:0] crc_data_in;                              //Signal that drives the CRC data into the module
reg sof;                                                        //Start of frame signal                              
wire crc_en, crc_reset;                                         //CRC enable & reset   
wire [31:0] crc_data_out;                                       //Ouput from the CRC32 module

/* CRC32 Module Instantiation */
crc32 #(.DATA_WIDTH(8)) 
crc_module(.clk(clk),
           .i_byte(crc_data_in),
           .i_crc_state(crc_state),
           .crc_en(crc_en),
           .o_crc_state(crc_next),
           .crc_out(crc_data_out)
           );

/* Sequential Logic */
always @(posedge clk) begin
    if(~reset_n) begin
        state_reg <= IDLE;
        tx_data_reg <= 8'h0;
        byte_ctr <= 3'h0;
        pckt_size <= 8'h0;
        mii_sdr <= 1'b0;
        axis_rdy_reg <= 1'b0;
        crc_en_reg <= 1'b0;
        crc_in_data_reg <= 1'b0;
        ifg_ctr <= 1'b0;
        rgmii_dv_reg <= 1'b0;
        rgmii_er_reg <= 1'b0;
    end else begin
        state_reg <= state_next;
        tx_data_reg <= tx_data_next;
        rgmii_dv_reg <= rgmii_dv_next;
        rgmii_er_reg <= rgmii_er_next;
        byte_ctr <= byte_ctr_next;
        pckt_size <= pckt_size_next;
        mii_sdr <= mii_sdr_next;
        axis_rdy_reg <= axis_rdy_next;
        ifg_ctr <= ifg_ctr_next;
                
        /* CRC Data Updates */
        crc_en_reg <= crc_en_next;
        crc_in_data_reg <= crc_in_data_next;        
        
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
assign crc_data_in = crc_in_data_reg;
assign crc_reset = (~reset_n || sof);

/* Next State Logic */
always @(*) begin
    /* Default Assignments */
    state_next = state_reg;
    tx_data_next = tx_data_reg;
    byte_ctr_next = byte_ctr;
    pckt_size_next = pckt_size;
    crc_in_data_next = crc_in_data_reg;
    ifg_ctr_next = ifg_ctr;
    mii_sdr_next = 1'b1;
    axis_rdy_next = 1'b0;
    crc_en_next = 1'b0;
    rgmii_dv_next = 1'b0;
    rgmii_er_next = 1'b0;
    sof = 1'b0;
 
    //If the RGMII is NOT ready to recieve data - pause the FSM operation
    if(!rgmii_mac_tx_rdy) begin
        tx_data_next = tx_data_reg;
        mii_sdr_next = mii_sdr;    
    end 
    //If the mii Select Signal is high and mii_sdr is raised, do not bring new data in
    //rather shift it for the SDR    
    else if(mii_select && mii_sdr) begin
        tx_data_next = {4'b0, tx_data_reg[7:4]};
        mii_sdr_next = 1'b0;
    end
    //If neither of the above options are met, proceed with the FSM
    else begin
        /* FSM Next State Logic */
        case(state_reg) 
            IDLE : begin
                mii_sdr_next = 1'b0;
                //If there is data in the FIFO, prepare to begin transaction
                if(s_tx_axis_tvalid) begin
                    sof = 1'b1;
                    byte_ctr_next = 3'b0;
                    mii_sdr_next = 1'b0;
                    pckt_size_next = 6'b0;
                    rgmii_dv_next = 1'b1;
                    state_next = PREAMBLE;
                end
            end
            PREAMBLE : begin
                rgmii_dv_next = 1'b1;
                //Set the s_axis_trdy flag high here, so we have incoming data when we enter the PACKET State
                if(byte_ctr == 3'd6) begin
                    if(~mii_select)
                        axis_rdy_next = 1'b1; 
                    
                    tx_data_next = ETH_HDR;
                    byte_ctr_next = byte_ctr + 1;
                end
                //If all 7 bytes of the Header have been sent, transmit the SFD  
                else if(byte_ctr == 3'd7) begin
                    tx_data_next = ETH_SFD;                    
                    mii_sdr_next = 1'b1;
                    byte_ctr_next = 3'd0;
                    pckt_size_next = 6'd0;
                    axis_rdy_next = 1'b1;     
                    state_next = PACKET;
                end else begin
                    tx_data_next = ETH_HDR;
                    mii_sdr_next = 1'b1;
                    byte_ctr_next = byte_ctr + 1;
                end
            end
            PACKET : begin
                rgmii_dv_next = 1'b1;
                crc_en_next = 1'b1;
                crc_in_data_next = s_tx_axis_tdata;
                axis_rdy_next = 1'b1;
                tx_data_next = s_tx_axis_tdata;
                mii_sdr_next = 1'b1;
                
                //Only increment the packet counter if it is less than 60. Once min frame size has been surpassed
                //packet counter is no longer needed
                if(pckt_size < (MIN_FRAME_WIDTH + 1))
                    pckt_size_next = pckt_size + 1;
                
                //If the last beat has arrived OR there is no more valid data in the FIFO
                //TODO: Possibly deal with error flag here for RGMII
                if(s_tx_axis_tlast || !s_tx_axis_tvalid) begin
                    if(pckt_size > (MIN_FRAME_WIDTH - 1)) begin
                        byte_ctr_next = 3'd3;
                        state_next = FCS;                        
                    end else begin
                        state_next = PADDING;
                    end
                end
            end
            PADDING : begin  
                rgmii_dv_next = 1'b1;          
                crc_in_data_next = ETH_PAD;
                tx_data_next = ETH_PAD;
                pckt_size_next = pckt_size + 1;                               
                crc_en_next = 1'b1;                                 
                mii_sdr_next = 1'b1; 
                
                //Once 59 bytes has been transmitted, shift to the FCS. The 60th byte will be transmitted
                //on the clock edge that triggers the state change    
                if(pckt_size > (MIN_FRAME_WIDTH-1)) begin                   
                    byte_ctr_next = 3'd3;
                    state_next = FCS;
                end 
            end            
            FCS : begin
                rgmii_dv_next = 1'b1;
                //Multiplex to determine which bytes to transmit
                case (byte_ctr)
                    3'b11 : tx_data_next = crc_data_out[7:0];
                    3'b10 : tx_data_next = crc_data_out[15:8];
                    3'b01 : tx_data_next = crc_data_out[23:16];
                    3'b00 : tx_data_next = crc_data_out[31:24];
                endcase
                mii_sdr_next = 1;
                
                //Ensure all 32 bits (4 bytes) of the CRC are transmitted
                if(byte_ctr == 0) begin                    
                    state_next = IFG;
                    ifg_ctr_next = 4'd0;
                end else
                    byte_ctr_next = byte_ctr - 1;
            end
            //According to IEEE, the required IFG bewteen packets is 96 bit-times
            //For 1Gbit this is 96ns, for 100Mbps this is 0.96us and 10Mbps is 9.6us
            IFG : begin
                mii_sdr_next = 1;
            
                if(ifg_ctr > IFG_SIZE ) 
                    state_next = IDLE;
                else
                    ifg_ctr_next = ifg_ctr + 1;
            end
        endcase
    end
end
           
/* Output Logic */         
assign rgmii_mac_tx_data = tx_data_reg;
assign s_tx_axis_trdy = axis_rdy_reg;
assign rgmii_mac_tx_dv = rgmii_dv_reg;


endmodule
