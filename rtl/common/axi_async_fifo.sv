`timescale 1ns / 1ps


module axi_async_fifo
#(
    parameter AXI_DATA_WIDTH = 8,       // Data width of teh AXI-Stream interface - This is NOT equivelent to the data width of the FIFO

    parameter PIPELINE_STAGES = 2,      // Number of pipeline stages AFTER the initial output register of the FIFO
    parameter FIFO_ADDR_WIDTH = 8,      // Address width of FIFO - Used to calculate teh depth using (2**FIFO_ADDR_WIDTH)

    /***************** Non-Configurable parameters *****************/
    parameter FIFO_DEPTH = 2**FIFO_ADDR_WIDTH,
    parameter FIFO_WORD_SIZE = AXI_DATA_WIDTH + 1   //The AXI data plus the tlast bit 
)
(
    /* AXI Master - Output/Read Signals */
    input wire m_aclk,
    input wire m_sresetn,
    output wire [AXI_DATA_WIDTH-1:0] m_axis_tdata,
    output wire m_axis_tlast,
    output wire m_axis_tvalid,
    input wire m_axis_trdy,

    /* AXI Slave - Input/Write Signals */
    input wire s_aclk,
    input wire s_sresetn,
    input wire [AXI_DATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tlast,
    input wire s_axis_tvalid,
    input wire s_axis_tuser,
    output wire s_axis_trdy
);

/* Write Domain Pointers */
reg [FIFO_ADDR_WIDTH:0] wr_ptr_binary = {FIFO_ADDR_WIDTH{1'b0}};
reg [FIFO_ADDR_WIDTH:0] wr_ptr_binary_next = {FIFO_ADDR_WIDTH{1'b0}};
reg [FIFO_ADDR_WIDTH:0] wr_ptr_packet_commit = {FIFO_ADDR_WIDTH{1'b0}};
reg [FIFO_ADDR_WIDTH:0] wr_ptr_grey = {FIFO_ADDR_WIDTH{1'b0}};
reg [FIFO_ADDR_WIDTH:0] wr_ptr_packet_commit_grey = {FIFO_ADDR_WIDTH{1'b0}};
reg [FIFO_ADDR_WIDTH:0] rd_ptr_grey_sync;
/* Read Domain Pointers */
reg [FIFO_ADDR_WIDTH:0] rd_ptr_binary = {FIFO_ADDR_WIDTH{1'b0}};
reg [FIFO_ADDR_WIDTH:0] rd_ptr_binary_next = {FIFO_ADDR_WIDTH{1'b0}};
reg [FIFO_ADDR_WIDTH:0] rd_ptr_grey = {FIFO_ADDR_WIDTH{1'b0}};
reg [FIFO_ADDR_WIDTH:0] wr_ptr_grey_sync;

/* BRAM Instantiation */
(* ram_style="block" *) reg [FIFO_WORD_SIZE-1:0] bram [0:FIFO_DEPTH-1]; 

/* Data-Path Registers */
reg s_frame_commit = 1'b0;
reg s_axis_trdy_out = 1'b0;
reg full;
reg empty;

/* Reset Logic */
reg [2:0] s_reset_sync = 3'b0;
reg [2:0] m_reset_sync = 3'b0;

wire m2s_reset_sync;
wire s2m_reset_sync;

////////////////////////////////////////////////////////////////////////////
// By Asynchronously setting the first FF in the sycnhronization pipeline
// we can avoid the problem of a timing violation when asserting the reset.
////////////////////////////////////////////////////////////////////////////

always @(posedge s_aclk or negedge s_sresetn) begin
    if(!s_sresetn)
        m_reset_sync[0] <= 1'b0;
    else
        m_reset_sync[0] <= 1'b1;
end

always @(posedge m_aclk or negedge m_sresetn) begin
    if(!m_sresetn)
        s_reset_sync[0] <= 1'b0;
    else
        s_reset_sync[0] <= 1'b1;
end

////////////////////////////////////////////////////////////////////////////
// Asynchronous resets can avoid the possible timing violation when asserting 
// the reset, however, when de-asserting the reset, asynchronous resets can
// cause a timing violation. Therefore, the asynchronous reset is synchronously 
// de-asserted.
////////////////////////////////////////////////////////////////////////////

cdc_signal_sync#(
    .PIPELINE(0),
    .WIDTH(1)
) slave_to_master_reset_sync (
    .i_dst_clk(m_aclk),
    .i_signal(m_reset_sync[0]),
    .o_signal_sync(s2m_reset_sync),
    .o_pulse_sync()
);

cdc_signal_sync#(
    .PIPELINE(0),
    .WIDTH(1)
) master_to_slave_reset_sync (
    .i_dst_clk(s_aclk),
    .i_signal(s_reset_sync[0]),
    .o_signal_sync(m2s_reset_sync),
    .o_pulse_sync()
);

/* Full & Empty Flag */
//assign full = (wr_ptr_grey == ({~rd_ptr_grey_sync[FIFO_ADDR_WIDTH:FIFO_ADDR_WIDTH-1], rd_ptr_grey_sync[FIFO_ADDR_WIDTH-2:0]}));
//assign empty = (rd_ptr_grey == wr_ptr_grey_sync);

always @(posedge s_aclk) begin
    if(!s_sresetn | !m2s_reset_sync)
        full <= 1'b0;
    else
        full <= (wr_ptr_grey == ({~rd_ptr_grey_sync[FIFO_ADDR_WIDTH:FIFO_ADDR_WIDTH-1], rd_ptr_grey_sync[FIFO_ADDR_WIDTH-2:0]})) 
                | (wr_ptr_grey_next == ({~rd_ptr_grey_sync[FIFO_ADDR_WIDTH:FIFO_ADDR_WIDTH-1], rd_ptr_grey_sync[FIFO_ADDR_WIDTH-2:0]}));
end

always @(posedge m_aclk) begin
    if(!m_sresetn | !s2m_reset_sync)
        empty <= 1'b1;
    else
        empty <= (rd_ptr_grey == wr_ptr_grey_sync) | (rd_ptr_grey_next == wr_ptr_grey_sync);
end

/* Writing Logic */

reg [FIFO_ADDR_WIDTH:0] wr_ptr_binary_precompute = {FIFO_ADDR_WIDTH{1'b0}};
reg [FIFO_ADDR_WIDTH:0] wr_ptr_grey_next = {FIFO_ADDR_WIDTH{1'b0}};

always @(posedge s_aclk) begin
    if(!s_sresetn | !m2s_reset_sync) begin
        wr_ptr_binary <= {FIFO_ADDR_WIDTH{1'b0}};
        wr_ptr_binary_next <= {{(FIFO_ADDR_WIDTH-1){1'b0}}, 1'b1};
        wr_ptr_packet_commit <= {FIFO_ADDR_WIDTH{1'b0}};
        wr_ptr_packet_commit_grey <= {FIFO_ADDR_WIDTH{1'b0}};
        wr_ptr_grey <= {FIFO_ADDR_WIDTH{1'b0}};
        s_frame_commit <= 1'b0;

        wr_ptr_binary_precompute <= {FIFO_ADDR_WIDTH{1'b0}};
        wr_ptr_grey_next <= {FIFO_ADDR_WIDTH{1'b0}};

    // AXI-Stream Handshake
    end else if(s_axis_tvalid & s_axis_trdy) begin

        wr_ptr_binary_precompute <= wr_ptr_binary + 3;
        wr_ptr_grey_next <= (wr_ptr_binary_precompute >> 1) ^ wr_ptr_binary_precompute;
        
        // Increment the Binary Pointer if the FIFO is not full
        if(!full) begin
            bram[wr_ptr_binary[FIFO_ADDR_WIDTH-1:0]] <= {s_axis_tdata, s_axis_tlast};
            
            // If the FIFO is not full, increment the write pointer
            wr_ptr_binary_next <= wr_ptr_binary_next + 1;
            wr_ptr_binary <= wr_ptr_binary_next;
            wr_ptr_grey <=  (wr_ptr_binary_next >> 1) ^ wr_ptr_binary_next;      
        end

        //If it is the last packet and it is not a bad packet; udpate the commited pointer
        if(s_axis_tlast & !s_axis_tuser) begin
            wr_ptr_packet_commit <= wr_ptr_binary_next;
            s_frame_commit <= 1'b1;
        //If the frame was a bad frame, return the write pointer to the last previously commited frame address
        end else if(s_axis_tuser) begin
            wr_ptr_binary <= wr_ptr_packet_commit;
        end
    end else begin
        s_frame_commit <= 1'b0;

        //Only update the grey pointer that is used in the read domain if we commit a new frame
        if(s_frame_commit) 
            wr_ptr_packet_commit_grey <= (wr_ptr_packet_commit >> 1) ^ wr_ptr_packet_commit;
    end
end

reg [FIFO_WORD_SIZE-1:0] m_axis_tdata_pipe [PIPELINE_STAGES:0];
reg [PIPELINE_STAGES:0] m_axis_tvalid_pipe = {PIPELINE_STAGES{1'b0}};

/* Pipeline Status signals */
wire pipe_wait = m_axis_tvalid_pipe[PIPELINE_STAGES] & !m_axis_trdy;
wire pipe_full = &m_axis_tvalid_pipe;
wire pipe_empty = (m_axis_tvalid_pipe == {PIPELINE_STAGES{1'b0}});

integer i;

/* Reading Logic */

reg [FIFO_ADDR_WIDTH:0] rd_ptr_binary_precompute = {FIFO_ADDR_WIDTH{1'b0}};
reg [FIFO_ADDR_WIDTH:0] rd_ptr_grey_next = {FIFO_ADDR_WIDTH{1'b0}};

always @(posedge m_aclk) begin
    if(!m_sresetn | !s2m_reset_sync) begin
        rd_ptr_binary <= {FIFO_ADDR_WIDTH{1'b0}};
        rd_ptr_binary_next <= {{(FIFO_ADDR_WIDTH-1){1'b0}}, 1'b1};
        rd_ptr_grey <= {FIFO_ADDR_WIDTH{1'b0}};   

        rd_ptr_grey_next <= {FIFO_ADDR_WIDTH{1'b0}};  
        rd_ptr_binary_precompute <= {FIFO_ADDR_WIDTH{1'b0}}; 
    end else begin

        rd_ptr_binary_precompute <= rd_ptr_binary + 3;
        rd_ptr_grey_next <= (rd_ptr_binary_precompute >> 1) ^ rd_ptr_binary_precompute;

        for(i = PIPELINE_STAGES; i > 0; i = i-1) begin
            //////////////////////////////////////////////////////////////////////////
            // There are 2 conditions where we want to shift data through the pipe:
            // 1) When there is a valid frame in the BRAM
            // 2) When we are actively reading data out of the FIFO
            // The pipe needs to be able to hold/wait if it is full but the slave is 
            // not ready for a transaction yet. The pipe also needs to empty its contents
            // completely for each frame.
            //////////////////////////////////////////////////////////////////////////
            if((~empty | ~pipe_empty) & !pipe_wait) begin
                //Pass data down the pipeline
                m_axis_tvalid_pipe[i] <= m_axis_tvalid_pipe[i-1];
                m_axis_tdata_pipe[i] <= m_axis_tdata_pipe[i-1];

                //Make sure to set the i-1 pipeline to 0 for tvalid
                m_axis_tvalid_pipe[i-1] <= 1'b0;          
            end
        end

        if(~empty & (~pipe_full | m_axis_trdy)) begin
            //Read data into the pipe from the BRAM
            m_axis_tdata_pipe[0] <= bram[rd_ptr_binary[FIFO_ADDR_WIDTH-1:0]];
            m_axis_tvalid_pipe[0] <= ~empty;
            
            //Update the read pointer if the FIFO is not empty
            rd_ptr_binary_next <= rd_ptr_binary_next + 1;
            rd_ptr_binary <= rd_ptr_binary_next;
            rd_ptr_grey <= (rd_ptr_binary_next >> 1) ^ rd_ptr_binary_next;   
        end
    end
end

/** Pointer Synchronization Logic **/

//Synchronization from read domain into write domain (read -> write)
sync_r2w #(
    .ADDR_WIDTH(FIFO_ADDR_WIDTH)
) read_to_write_sync(
    .clk(s_aclk),
    .reset_n(s_sresetn),
    .i_rd_ptr(rd_ptr_grey),
    .o_rd_ptr(rd_ptr_grey_sync)
);

//Synchornization between the write and read domains (write -> read)
sync_w2r #(
    .ADDR_WIDTH(FIFO_ADDR_WIDTH)
) write_to_read_sync(
    .clk(m_aclk),
    .reset_n(m_sresetn),
    .i_wr_ptr(wr_ptr_packet_commit_grey), 
    .o_wr_ptr(wr_ptr_grey_sync)
);

/* Output Signals */

assign s_axis_trdy = ~full & m2s_reset_sync;    
assign m_axis_tvalid = m_axis_tvalid_pipe[PIPELINE_STAGES]; 
assign m_axis_tdata = m_axis_tdata_pipe[PIPELINE_STAGES][FIFO_WORD_SIZE-1:1];
assign m_axis_tlast = m_axis_tdata_pipe[PIPELINE_STAGES][0];

endmodule