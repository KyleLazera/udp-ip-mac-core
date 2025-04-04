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

module tx_mac
#(
    parameter DATA_WIDTH = 8
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
    input wire mii_select,                                  //Configures data rate (Double Data Rate (DDR) or Single Data Rate (SDR))    
    input wire [1:0] link_speed                             //Indicates link speed - used for IFG calculation
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
state_type state_reg;                               //Holds the current and next State 
reg [DATA_WIDTH-1:0] tx_data_reg;                   //Holds data to be transmitted to RGMII
reg rgmii_dv_reg;                                   //Data Valid signal for the RGMII
reg rgmii_er_reg;                                   //Error Signal for teh RGMII
reg [2:0] byte_ctr;                                 //Counts the number of bytes transmitted
reg [7:0] pckt_size;                                //Counts size of payload in bytes (Ensure they payload is between 46 - 1500 bytes) 
reg mii_sdr;                                        //Indicates the next data transfer needs to shift byte by 4 (for SDR in MII mode)
reg axis_rdy_reg;                                   //Implements a FF between the outgoing s_tx_axis_rdy signal and FIFO  

/* CRC32 Interface Signals */
reg [31:0] crc_state, crc_next;                                 //Holds the output state of the CRC32 module                                       
reg [DATA_WIDTH-1:0] crc_in_data_reg;                           //Holds the input values for the CRC32 module                               
reg crc_en_reg;                                                 //Register that holds crc_en state 
wire [DATA_WIDTH-1:0] crc_data_in;                              //Signal that drives the CRC data into the module
reg sof;                                                        //Start of frame signal                              
wire crc_en, crc_reset;                                         //CRC enable & reset   
wire [31:0] crc_data_out;                                       //Ouput from the CRC32 module

/* CRC32 Module Instantiation */
crc32 #(.DATA_WIDTH(8)) 
crc_module(.i_byte(crc_data_in),
           .i_crc_state(crc_state),
           .crc_en(crc_en),
           .o_crc_state(crc_next),
           .crc_out(crc_data_out)
           );

/* CRC Logic  */
always @(posedge clk) begin
    // Logic to update CRC State 
    if(crc_reset)
        crc_state <= 32'hFFFFFFFF;
    else if(crc_en)
        crc_state <= crc_next;
    else
        crc_state <= crc_state;
end

assign sof = s_tx_axis_tvalid && (state_reg == IDLE);
assign crc_en = crc_en_reg;
assign crc_data_in = crc_in_data_reg;
assign crc_reset = (~reset_n || sof);           

/* IFG Logic */
reg [10:0] ifg_ctr, ifg_ctr_next;                               //Counter to count up-to teh inter frame gap
reg [10:0] ifg;                                                 //inter frame gap value that will be used for comparison

////////////////////////////////////////////////////////////////////////////////
// According to the IEEE 802.3, the inter-frame gap must constitute 96
// bit times. For 10mbps link and a clock freq of 2.5MHz, this corresponds 
// to 9.6us (9600ns), for 100mbps with a clock freq of 25MHz this corresponds 
// to .96us (960ns) and for 1gbps with a clock freq of 125MHz this corresponds
// to 96ns.
// Because the tx mac always operates at 125MHz, the ifg to count up to can
// simply be adjusted based on teh link speed.
////////////////////////////////////////////////////////////////////////////////

always@(posedge clk) begin
    if(reset_n)
        ifg <= 11'd12;
    else begin
        case(link_speed) 
            2'b00: ifg <= 11'd1200;
            2'b01: ifg <= 11'd120;
            2'b10: ifg <= 11'd12;
            default: ifg <= 11'd12;
        endcase
    end
end

/* Packet Encapsulation Logic */
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
        //Default assignments 
        mii_sdr <= 1'b1;
        axis_rdy_reg <= 1'b0;
        crc_en_reg <= 1'b0;  
        rgmii_dv_reg <= 1'b0;
        rgmii_er_reg <= 1'b0;     

        //If the RGMII is NOT ready to recieve data - pause the FSM operation
        if(!rgmii_mac_tx_rdy) begin
            mii_sdr <= mii_sdr;
            rgmii_dv_reg <= rgmii_dv_reg;
        end
        //If the mii Select Signal is high and mii_sdr is raised, do not bring new data in
        //rather shift it for the SDR            
        else if(mii_select && mii_sdr)  begin
            tx_data_reg <= {4'b0, tx_data_reg[7:4]};
            mii_sdr <= 1'b0;
            rgmii_dv_reg <= rgmii_dv_reg; 
        end
        //If neither of the above options are met, proceed with the FSM
        /* State Machine */
        else begin
            case(state_reg)
                IDLE: begin
                    mii_sdr <= 1'b0;
                    //If there is data in the FIFO, prepare to begin transaction
                    if(s_tx_axis_tvalid) begin
                        byte_ctr <= 3'b0;
                        mii_sdr <= 1'b0;
                        pckt_size <= 6'b0;
                        state_reg <= PREAMBLE;
                    end
                end
                PREAMBLE : begin
                    rgmii_dv_reg <= 1'b1;

                    //If we have recieved out 6th byte of the preamble
                    if(byte_ctr == 3'd6) begin
                        tx_data_reg <= ETH_HDR;
                        byte_ctr <= byte_ctr + 1;
                        //axis_rdy_reg <= ~mii_select;
                    end
                    //If all 7 bytes of the Header have been sent, transmit the SFD  
                    else if(byte_ctr == 3'd7) begin
                        tx_data_reg <= ETH_SFD;
                        mii_sdr <= 1'b1;
                        byte_ctr <= 3'b0;
                        pckt_size <= 6'd0;
                        axis_rdy_reg <= ~mii_select;
                        state_reg <= PACKET;
                    end 
                    else begin
                        tx_data_reg <= ETH_HDR;
                        mii_sdr <= 1'b1;
                        byte_ctr <= byte_ctr + 1;
                    end
                end
                PACKET: begin
                    rgmii_dv_reg <= 1'b1;
                    crc_en_reg <= 1'b1;
                    crc_in_data_reg <= s_tx_axis_tdata;
                    axis_rdy_reg <= 1'b1;
                    tx_data_reg <= s_tx_axis_tdata;
                    mii_sdr <= 1'b1;

                    //Only increment the packet counter if it is less than 60. Once min frame size has been surpassed
                    //packet counter is no longer needed
                    if(pckt_size < (MIN_FRAME_WIDTH + 1)) 
                        pckt_size <= pckt_size + 1;                    
                    

                    //If the last beat has arrived OR there is no more valid data in the FIFO
                    if(s_tx_axis_tlast) begin
                        axis_rdy_reg <= mii_select;                    
                        if(pckt_size > (MIN_FRAME_WIDTH - 1)) begin
                            crc_en_reg <= 1'b0;
                            byte_ctr <= 3'd3;
                            state_reg <= FCS;                        
                        end else begin
                            state_reg <= PADDING;
                        end
                    end
                end
                PADDING: begin
                    rgmii_dv_reg <= 1'b1;          
                    crc_in_data_reg <= ETH_PAD;
                    tx_data_reg <= ETH_PAD;
                    pckt_size <= pckt_size + 1;                               
                    crc_en_reg <= 1'b1;                                 
                    mii_sdr <= 1'b1; 
                
                    //Once 59 bytes has been transmitted, shift to the FCS. The 60th byte will be transmitted
                    //on the clock edge that triggers the state change    
                    if(pckt_size > (MIN_FRAME_WIDTH-1)) begin                   
                        crc_en_reg <= 1'b0;
                        byte_ctr <= 3'd3;
                        state_reg <= FCS;
                    end                     
                end
                FCS : begin
                    rgmii_dv_reg <= 1'b1;
                    //Multiplex to determine which bytes to transmit
                    case (byte_ctr)
                        3'b11 : tx_data_reg <= crc_data_out[7:0];
                        3'b10 : tx_data_reg <= crc_data_out[15:8];
                        3'b01 : tx_data_reg <= crc_data_out[23:16];
                        3'b00 : tx_data_reg <= crc_data_out[31:24];
                    endcase
                    mii_sdr <= 1;
                
                    //Ensure all 32 bits (4 bytes) of the CRC are transmitted
                    if(byte_ctr == 0) begin                    
                        state_reg <= IFG;
                        ifg_ctr <= 11'd0;
                    end else
                        byte_ctr <= byte_ctr - 1;
                end
                //According to IEEE, the required IFG bewteen packets is 96 bit-times
                //For 1Gbit this is 96ns, for 100Mbps this is 0.96us and 10Mbps is 9.6us
                IFG : begin
                    mii_sdr <= 1;
            
                    if(ifg_ctr > ifg) 
                        state_reg <= IDLE;
                    else
                        ifg_ctr <= ifg_ctr + 1;
                end                
            endcase
        end
    end
end
           
/* Output Logic */         
assign rgmii_mac_tx_data = tx_data_reg;
assign s_tx_axis_trdy = axis_rdy_reg;
assign rgmii_mac_tx_dv = rgmii_dv_reg;
assign rgmii_mac_tx_er = rgmii_er_reg;
endmodule
