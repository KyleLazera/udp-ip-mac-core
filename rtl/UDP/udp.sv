`timescale 1ns / 1ps

/*
 * This module is the top-level UDP module, and is responsible for computing the UDP checksum
 * & the Payload size in-line with the UDP payload (For the TX Data Path). Once the module computes
 * these values, it also outputs them so they can be used by the Ethernet MAC for Insertion before 
 * transmitting the packet.
 */

module udp#(
    parameter AXI_DATA_WIDTH = 8,
    parameter MAX_PAYLOAD = 1472
)(
    input wire i_clk,
    input wire i_reset_n,

    /********** UDP TX Signals **********/

    /* Input IP & UDP Header Fields */
    output wire s_udp_tx_hdr_trdy,
    input wire s_udp_tx_hdr_tvalid,
    input wire [15:0] s_udp_tx_src_port,
    input wire [15:0] s_udp_tx_dst_port,
    input wire [31:0] s_ip_tx_src_ip_addr,                               
    input wire [31:0] s_ip_tx_dst_ip_addr, 
    input wire [7:0] s_ip_tx_protocol,                                   

    /* Input AXI-Stream Payload */
    input wire [AXI_DATA_WIDTH-1:0] s_tx_axis_tdata,
    input wire s_tx_axis_tvalid,
    input wire s_tx_axis_tlast,
    output wire s_tx_axis_trdy,

    /* Output UDP Header Fields */
    output wire m_udp_tx_hdr_valid,
    output wire [15:0] m_udp_tx_length,
    output wire [15:0] m_udp_tx_checksum,

    /* Output AXI-Stream UDP Payload */
    output wire [AXI_DATA_WIDTH-1:0] m_tx_axis_tdata,
    output wire m_tx_axis_tvalid,
    output wire m_tx_axis_tlast,
    input wire m_tx_axis_trdy,

    /********** UDP RX Signals **********/

    /* Encapsulated UDP Input Payload - From IP*/
    input wire [AXI_DATA_WIDTH-1:0] s_rx_axis_tdata,
    input wire s_rx_axis_tvalid,
    input wire s_rx_axis_tlast,
    output wire s_rx_axis_trdy,

    /* AXI-Stream De-encapsulated Payload - Output Data */
    output wire [AXI_DATA_WIDTH-1:0] m_rx_axis_tdata,
    output wire m_rx_axis_tvalid,
    output wire m_rx_axis_tlast,
    input wire m_rx_axis_trdy,

    /* UDP Header Data */
    input wire s_udp_rx_hdr_trdy,
    output wire s_udp_rx_hdr_tvalid,
    output wire [15:0] s_udp_rx_src_port,
    output wire [15:0] s_udp_rx_dst_port,
    output wire [15:0] s_udp_rx_length_port,
    output wire [15:0] s_udp_rx_hdr_checksum
);

/* UDP Checksum & Length Calculation in Parallel */

localparam PCKT_CNTR_WIDTH = $clog2(MAX_PAYLOAD+1);
localparam FIELD_WIDTH_DIFF = 16 - PCKT_CNTR_WIDTH;
localparam UDP_HEADER_LENGTH = 8;

localparam IDLE = 2'b00;
localparam HDR_CHECKSUM = 2'b01;
localparam PAYLOAD_CHECKSUM = 2'b10;
localparam FINAL_CALC = 2'b11;

// UDP Checksum is the same as the IP checksum algorithm
function [15:0] udp_checksum(input [15:0] sum, input [15:0] hdr_field);
   //Intermediary sum
   reg [16:0] int_sum;
   begin
      int_sum = sum + hdr_field;
      udp_checksum = int_sum[15:0] + int_sum[16]; 
   end 
endfunction : udp_checksum

// IP & UDP Header fields used for checksum Calculation
reg m_udp_hdr_valid_reg = 1'b0;
reg [31:0] ip_src_addr = 16'b0;
reg [31:0] ip_dst_addr = 16'b0;
reg [15:0] ip_protocol = 8'b0;
reg [15:0] udp_src_port = 16'b0;
reg [15:0] udp_dst_port = 16'b0;
reg [15:0] udp_pckt_length = 16'b0;
reg [15:0] udp_checksum_reg = 16'b0;

// Intermediary/Control Signals
reg [1:0] state = IDLE;
reg [PCKT_CNTR_WIDTH-1:0] pckt_cntr = {PCKT_CNTR_WIDTH{1'b0}};
reg [15:0] udp_checksum_sum = 16'b0;
reg [AXI_DATA_WIDTH-1:0] udp_checksum_value = 8'b0;

// Packet Size Counter
always @(posedge i_clk) begin
    if(!i_reset_n) begin
        state <= IDLE;
        pckt_cntr <= {PCKT_CNTR_WIDTH{1'b0}};
        udp_checksum_sum <= 16'b0;
        m_udp_hdr_valid_reg <= 1'b0;
    end else begin
        case(state)
            IDLE: begin
                
                // If the header valid is data, and teh tx UDP module has sampled the, then latch
                // the data to use for the checksum
                if(s_udp_tx_hdr_tvalid & s_udp_tx_hdr_trdy) begin
                    ip_src_addr <= s_ip_tx_src_ip_addr;
                    ip_dst_addr <= s_ip_tx_dst_ip_addr;
                    ip_protocol <= {8'h00, s_ip_tx_protocol};
                    udp_src_port <= s_udp_tx_src_port;
                    udp_dst_port <= s_udp_tx_dst_port;

                    udp_checksum_sum <= 16'b0;
                    m_udp_hdr_valid_reg <= 1'b0;
                    pckt_cntr <= {PCKT_CNTR_WIDTH{1'b0}};
                    //Move to the Header State
                    state <= HDR_CHECKSUM;
                end
            end
            HDR_CHECKSUM: begin

                pckt_cntr <= pckt_cntr + 1;

                // While the tx UDP module drives the UDP header values, calculate the UDP checksum value
                // for the IP pseudo-header + the UDP header values we know
                case(pckt_cntr)
                    'd0: udp_checksum_sum <= udp_checksum(udp_checksum_sum, ip_src_addr[31:16]);
                    'd1: udp_checksum_sum <= udp_checksum(udp_checksum_sum, ip_src_addr[15:0]);
                    'd2: udp_checksum_sum <= udp_checksum(udp_checksum_sum, ip_dst_addr[31:16]);
                    'd3: udp_checksum_sum <= udp_checksum(udp_checksum_sum, ip_dst_addr[15:0]);
                    'd4: udp_checksum_sum <= udp_checksum(udp_checksum_sum, ip_protocol);
                    'd5: udp_checksum_sum <= udp_checksum(udp_checksum_sum, udp_src_port);
                    'd6: begin
                        udp_checksum_sum <= udp_checksum(udp_checksum_sum, udp_dst_port);
                        pckt_cntr <= UDP_HEADER_LENGTH;
                        state <= PAYLOAD_CHECKSUM;
                    end
                endcase
            end
            PAYLOAD_CHECKSUM: begin

                if(s_tx_axis_trdy & s_tx_axis_tvalid) begin

                    // Odd Counter (lsb == 0)
                    if(pckt_cntr[0] == 1'b0) begin

                        // If the last byte is recieved and the packet size is odd, add padding to the 
                        // input checksum value (to make a 16-bit field)
                        if(s_tx_axis_tvalid & s_tx_axis_trdy & s_tx_axis_tlast) begin
                            udp_checksum_sum <= udp_checksum(udp_checksum_sum, {s_tx_axis_tdata, 8'h00});
                            udp_pckt_length <= pckt_cntr + 1;
                            state <= FINAL_CALC;
                        end else begin
                            udp_checksum_value <= s_tx_axis_tdata;
                        end
                    // Even Counter (lsb == 1)
                    end else begin
                        udp_checksum_sum <= udp_checksum(udp_checksum_sum, {udp_checksum_value, s_tx_axis_tdata});

                        if(s_tx_axis_tvalid & s_tx_axis_trdy & s_tx_axis_tlast) begin
                            udp_pckt_length <= pckt_cntr + 1;
                            state <= FINAL_CALC;
                        end
                    end

                    // If we have valid data being transmitted, count this byte
                    if(s_tx_axis_tvalid & s_tx_axis_trdy & !s_tx_axis_tlast) 
                        pckt_cntr <= pckt_cntr + 1;
                end
        
            end
            FINAL_CALC: begin
                m_udp_hdr_valid_reg <= 1'b1;
                pckt_cntr <= {PCKT_CNTR_WIDTH{1'b0}};
                udp_checksum_reg <= ~udp_checksum(udp_checksum_sum, udp_pckt_length);
                udp_checksum_sum <= 16'b0;
                state <= IDLE;
            end
        endcase
    end
end

/* Checksum Output Fields */
assign m_udp_tx_hdr_valid = m_udp_hdr_valid_reg;
assign m_udp_tx_length = udp_pckt_length;
assign m_udp_tx_checksum = udp_checksum_reg;

/* UDP TX Module */

udp_tx#(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))
tx_udp(
    .i_clk(i_clk),
    .i_reset_n(i_reset_n),

    /* UDP Header Inputs */
    .s_udp_hdr_trdy(s_udp_tx_hdr_trdy),
    .s_udp_hdr_tvalid(s_udp_tx_hdr_tvalid),
    .s_udp_src_port(s_udp_tx_src_port),
    .s_udp_dst_port(s_udp_tx_dst_port),

    /* UDP Payload Inputs */
    .s_tx_axis_tdata(s_tx_axis_tdata),
    .s_tx_axis_tvalid(s_tx_axis_tvalid),
    .s_tx_axis_tlast(s_tx_axis_tlast),
    .s_tx_axis_trdy(s_tx_axis_trdy),

    /* Encapsulated UDP Frame Output */
    .m_tx_axis_tdata(m_tx_axis_tdata),
    .m_tx_axis_tvalid(m_tx_axis_tvalid),
    .m_tx_axis_tlast(m_tx_axis_tlast),
    .m_tx_axis_trdy(m_tx_axis_trdy)
);

/* UDP RX Module */

udp_rx#(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))
rx_udp(
    .i_clk(i_clk),
    .i_reset_n(i_reset_n),

    /* RX UDP Frame */
    .s_rx_axis_tdata(s_rx_axis_tdata),
    .s_rx_axis_tvalid(s_rx_axis_tvalid),
    .s_rx_axis_tlast(s_rx_axis_tlast),
    .s_rx_axis_trdy(s_rx_axis_trdy),

    /* RX UDP Payload */
    .m_rx_axis_tdata(m_rx_axis_tdata),
    .m_rx_axis_tvalid(m_rx_axis_tvalid),
    .m_rx_axis_tlast(m_rx_axis_tlast),
    .m_rx_axis_trdy(m_rx_axis_trdy),

    /* RX UDP Header Fields */
    .m_udp_hdr_trdy(s_udp_rx_hdr_trdy),
    .m_udp_hdr_tvalid(s_udp_rx_hdr_tvalid),
    .m_udp_src_port(s_udp_rx_src_port),
    .m_udp_dst_port(s_udp_rx_dst_port),
    .m_udp_length_port(s_udp_rx_length_port),
    .m_udp_hdr_checksum(s_udp_rx_hdr_checksum)
);


endmodule : udp