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

localparam UDP_HDR_PIPELINE = 5;
localparam PCKT_CNTR_WIDTH = $clog2(MAX_PAYLOAD+1);
localparam FIELD_WIDTH_DIFF = 16 - PCKT_CNTR_WIDTH;
localparam UDP_HEADER_LENGTH = 8;

localparam CHECKSUM_ACCUMULATE = 3'b000;
localparam ODD_LAST_BYTE = 3'b001;
localparam HEADER_SUM_COMBINE = 3'b010;
localparam SUM_MERGE = 3'b011;
localparam FINAL_FOLD = 3'b100;

// IP & UDP Header fields used for checksum Calculation
reg m_udp_hdr_valid_reg = 1'b0;
reg [31:0] ip_src_addr = 16'b0;
reg [31:0] ip_dst_addr = 16'b0;
reg [15:0] ip_protocol = 8'b0;
reg [15:0] udp_src_port = 16'b0;
reg [15:0] udp_dst_port = 16'b0;
reg [15:0] udp_pckt_length = 16'b0;
reg [16:0] udp_checksum_reg = 17'b0;

// Intermediary/Control Signals
reg [2:0] state = CHECKSUM_ACCUMULATE;
reg [PCKT_CNTR_WIDTH-1:0] pckt_cntr = {PCKT_CNTR_WIDTH{1'b0}};
reg hdr_latched = 1'b0;
reg s_tx_udp_trdy;

// Checksum Signals 
reg [AXI_DATA_WIDTH-1:0] udp_checksum_value = 8'b0;
reg [16:0] int_checksum_sum = 17'b0;
reg [15:0] checksum_sum_carry = 16'b0;

reg [16:0] src_ip_checksum_precompute = 17'b0;
reg [16:0] dst_ip_checksum_precompute = 17'b0;
reg [16:0] udp_port_checksum_precompute = 17'b0;

reg [15:0] src_ip_checksum_carry = 16'b0;
reg [15:0] dst_ip_checksum_carry = 16'b0;
reg [15:0] udp_port_checksum_carry = 16'b0;

reg [16:0] ip_addr_checksum_precompute = 17'b0;
reg [16:0] port_protocol_checksum_precompute = 17'b0;

reg [15:0] ip_addr_checksum_carry = 16'b0;
reg [15:0] port_protocol_checksum_carry = 16'b0;

reg [16:0] pseudo_hdr_checksum = 17'b0;
reg [15:0] pseudo_hdr_checksum_carry = 16'b0;

reg [16:0] udp_hdr_checksum = 17'b0;
reg [15:0] udp_hdr_checksum_carry = 16'b0;

//////////////////////////////////////////////////////////////////////////////////////////////////
// UDP Checksum Algorithm:
// The UDP checksum uses 1's complement summation over 16-bit words. This includes the UDP payload,
// UDP header, and a pseudo-header (source IP, destination IP, and protocol). When two 16-bit words 
// are added, any carry out must be folded back and added to the result.
// 
// Since addition is associative, the checksum of the pseudo-header and UDP header can be
// precomputed in parallel with the payload sum. This means that the UDP checksum algorithm can be
// pipelined more, and therefore improve timing.
//////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge i_clk) begin

    if(hdr_latched) begin

        // Wrap the carry for each pre-computed UDP Checksum value
        src_ip_checksum_carry <= src_ip_checksum_precompute[15:0] + src_ip_checksum_precompute[16];
        dst_ip_checksum_carry <= dst_ip_checksum_precompute[15:0] + dst_ip_checksum_precompute[16];
        udp_port_checksum_carry <= udp_port_checksum_precompute[15:0] + udp_port_checksum_precompute[16];

        // Add together each of the pre-computed values above with the carry folded over
        ip_addr_checksum_precompute <= src_ip_checksum_carry + dst_ip_checksum_carry;
        port_protocol_checksum_precompute <= udp_port_checksum_carry + ip_protocol;

        // Fold the carry again
        ip_addr_checksum_carry <= ip_addr_checksum_precompute[15:0] + ip_addr_checksum_precompute[16];
        port_protocol_checksum_carry <= port_protocol_checksum_precompute[15:0] + port_protocol_checksum_precompute[16];

        // Calculate the psuedo-header UDP checksum
        pseudo_hdr_checksum <= ip_addr_checksum_carry + port_protocol_checksum_carry;
        pseudo_hdr_checksum_carry <= pseudo_hdr_checksum[15:0] + pseudo_hdr_checksum[16];
    end
end

/* UDP Data Pipeline Logic */

reg [AXI_DATA_WIDTH-1:0] s_tx_tdata_pipe [UDP_HDR_PIPELINE-1:0];
reg [UDP_HDR_PIPELINE-1:0] s_tx_tvalid_pipe = 5'b0;
reg [UDP_HDR_PIPELINE-1:0] s_tx_tlast_pipe = 5'b0;

wire pipe_rdy = !pipe_full & !pipe_wait;
wire pipe_empty = (|s_tx_tvalid_pipe == 5'b0);
wire pipe_full = &s_tx_tvalid_pipe;
wire pipe_wait = s_tx_tvalid_pipe[UDP_HDR_PIPELINE-1] & !s_tx_udp_trdy;

integer i;

////////////////////////////////////////////////////////////////////////////////////
// Before the UDP tx module can recieve and transmit payload data, it first drives out
// the UDP header which consists of 8 bytes. Therefore, there are 8 clock cycles where
// this module would remain idle. This pipeline allows the payload data to be recieved
// early (while the UDP header is being transmitted) thereby giving extra clock cycles
// for the UDP checksum. This means the checksum algorithm can be pipelined to improve 
// timing.
////////////////////////////////////////////////////////////////////////////////////

always @(posedge i_clk) begin
        
    for(i = UDP_HDR_PIPELINE-1; i > 0; i = i-1) begin

        // If the pipeline is not empty and we are not in a pipe wait state, then 
        // we can shift data down the pipe
        if(!pipe_empty & (!pipe_wait | (|s_tx_tlast_pipe != 5'b0))) begin
            s_tx_tdata_pipe[i] <= s_tx_tdata_pipe[i-1];
            s_tx_tvalid_pipe[i] <= s_tx_tvalid_pipe[i-1];
            s_tx_tlast_pipe[i] <= s_tx_tlast_pipe[i-1];

            s_tx_tvalid_pipe[i-1] <= 1'b0;
            s_tx_tlast_pipe[i-1] <= 1'b0;
        end
    end

    // If there is valid data in the upstream module then we should be driving
    // data into the pipeline, so long as it is not already full/the slave is not ready
    if(s_tx_axis_tvalid & (!pipe_full | s_tx_udp_trdy)) begin
        s_tx_tdata_pipe[0] <= s_tx_axis_tdata;
        s_tx_tvalid_pipe[0] <= s_tx_axis_tvalid;
        s_tx_tlast_pipe[0] <= s_tx_axis_tlast;
    end

end

/* Packet Counting & Payload Checksum Logic */

always @(posedge i_clk) begin
    if(!i_reset_n) begin
        state <= CHECKSUM_ACCUMULATE;
        hdr_latched <= 1'b0;
        pckt_cntr <= UDP_HEADER_LENGTH;
        m_udp_hdr_valid_reg <= 1'b0;
    end else begin

        // If the header handshake is valid, sample the UDP/IP headers and init all the control signals
        // for the incoming packet 
        if(s_udp_tx_hdr_tvalid & s_udp_tx_hdr_trdy) begin
            // Latch Header values 
            ip_src_addr <= s_ip_tx_src_ip_addr;
            ip_dst_addr <= s_ip_tx_dst_ip_addr;
            ip_protocol <= {8'h00, s_ip_tx_protocol};
            udp_src_port <= s_udp_tx_src_port;
            udp_dst_port <= s_udp_tx_dst_port;

            // Reset/Initialize Control Signals
            m_udp_hdr_valid_reg <= 1'b0;
            pckt_cntr <= UDP_HEADER_LENGTH;
            hdr_latched <= 1'b1;

            // Precompute 16-bit words for the UDP checksum
            src_ip_checksum_precompute <= s_ip_tx_src_ip_addr[31:16] + s_ip_tx_src_ip_addr[15:0];
            dst_ip_checksum_precompute <= s_ip_tx_dst_ip_addr[31:16] + s_ip_tx_dst_ip_addr[15:0];
            udp_port_checksum_precompute <= s_udp_tx_src_port + s_udp_tx_dst_port;
        end

        /* Checksum Calculation State Machine */
        case(state)
            CHECKSUM_ACCUMULATE: begin
                
                // If the AXI-Stream handshake is valid, sample the UDP payload data 
                if(s_tx_axis_trdy & s_tx_axis_tvalid) begin

                    pckt_cntr <= pckt_cntr + 1;

                    // Odd Byte Recieved (lsb == 0)
                    if(pckt_cntr[0] == 1'b0) begin
                        checksum_sum_carry <= int_checksum_sum[15:0] + int_checksum_sum[16];
                        udp_checksum_value <= s_tx_axis_tdata;

                        if(s_tx_axis_tlast) begin
                            hdr_latched <= 1'b0;
                            state <= ODD_LAST_BYTE;
                        end

                    end

                    // Even Byte Recieved (lsb == 1)
                    if(pckt_cntr[0] == 1'b1) begin
                        int_checksum_sum <= checksum_sum_carry + {udp_checksum_value, s_tx_axis_tdata};

                        if(s_tx_axis_tlast) begin
                            hdr_latched <= 1'b0;
                            state <= HEADER_SUM_COMBINE;
                        end

                    end
                end
            end
            // If teh last byte triggered an odd packet size, add a padding (8'h00) byte to the UDP byte
            // to make it 16 bits
            ODD_LAST_BYTE: begin
                int_checksum_sum <= checksum_sum_carry + {udp_checksum_value, 8'h00};
                state <= HEADER_SUM_COMBINE;
            end
            // Add precomputed pseudo-header checksum and packet length
            HEADER_SUM_COMBINE: begin
                udp_hdr_checksum <= pseudo_hdr_checksum_carry + pckt_cntr;
                checksum_sum_carry <= int_checksum_sum[15:0] + int_checksum_sum[16];
                state <= SUM_MERGE;
            end
            // Merge header and payload checksums into one running total
            SUM_MERGE: begin
                udp_hdr_checksum_carry <= udp_hdr_checksum[15:0] + udp_hdr_checksum[16];
                state <= FINAL_FOLD;
            end
            // Final carry fold and output the computed UDP checksum
            FINAL_FOLD: begin
                m_udp_hdr_valid_reg <= 1'b1;
                pckt_cntr <= UDP_HEADER_LENGTH;
                int_checksum_sum <=17'b0;
                checksum_sum_carry <= 16'b0;

                udp_checksum_reg <= checksum_sum_carry + udp_hdr_checksum_carry;
                udp_pckt_length <= pckt_cntr;

                state <= CHECKSUM_ACCUMULATE;
            end
        endcase

    end
end

/* Checksum Output Fields */
assign m_udp_tx_hdr_valid = m_udp_hdr_valid_reg;
assign m_udp_tx_length = udp_pckt_length;
assign m_udp_tx_checksum = ~(udp_checksum_reg[15:0] + udp_checksum_reg[16]);

assign s_tx_axis_trdy = (s_tx_udp_trdy | pipe_rdy);

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

    .s_tx_axis_tdata(s_tx_tdata_pipe[UDP_HDR_PIPELINE-1]),
    .s_tx_axis_tvalid(s_tx_tvalid_pipe[UDP_HDR_PIPELINE-1]),
    .s_tx_axis_tlast(s_tx_tlast_pipe[UDP_HDR_PIPELINE-1]),
    .s_tx_axis_trdy(s_tx_udp_trdy), 

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