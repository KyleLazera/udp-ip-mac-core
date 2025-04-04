`timescale 1ns / 1ps

/* todo:
* - Add safety mechanism for FIFO depth being a power of 2
* - Add packet dropping mechanism/almost empty or full flags
* - Handle resets by implement a reset strategy
*/


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
reg [FIFO_ADDR_WIDTH:0] wr_ptr_packet_commit = {FIFO_ADDR_WIDTH{1'b0}};
reg [FIFO_ADDR_WIDTH:0] wr_ptr_grey = {FIFO_ADDR_WIDTH{1'b0}};
reg [FIFO_ADDR_WIDTH:0] wr_ptr_packet_commit_grey = {FIFO_ADDR_WIDTH{1'b0}};
reg [FIFO_ADDR_WIDTH:0] rd_ptr_grey_sync = {FIFO_ADDR_WIDTH{1'b0}};

/* Read Domain Pointers */
reg [FIFO_ADDR_WIDTH:0] rd_ptr_binary = {FIFO_ADDR_WIDTH{1'b0}};
reg [FIFO_ADDR_WIDTH:0] rd_ptr_grey = {FIFO_ADDR_WIDTH{1'b0}};
reg [FIFO_ADDR_WIDTH:0] wr_ptr_grey_sync = {FIFO_ADDR_WIDTH{1'b0}};

/* BRAM Instantiation */
(* ram_style="block" *) reg [FIFO_WORD_SIZE-1:0] bram [0:FIFO_DEPTH-1]; 

reg s_frame_commit = 1'b0;
reg s_axis_trdy_out = 1'b0;

wire full;
wire empty;

reg m_sresetn = 1'b1;
reg m_sreset_sync;
reg wr_reset_stretch = 1'b1;

/* Reset Logic - Stretch the reset from the write domain and synchronize
 * it into the read domain. Only lower the stretched input reset once the 
 * synchornized reset has entered into the read domain.
 */

 always @(posedge s_aclk) begin
    wr_reset_stretch <= (!s_sresetn | ~wr_reset_stretch) & (!s_sresetn & m_sreset_sync);
 end

cdc_signal_sync #(
    .PIPELINE(0),
    .WIDTH(1)
) reset_wr2rd_sync (
    .i_dst_clk(m_aclk),
    .i_signal(~wr_reset_stretch),
    .o_signal_sync(m_sresetn),
    .o_pulse_sync()
);

cdc_signal_sync #(
    .PIPELINE(0),
    .WIDTH(1)
) reset_rd2wr_sync (
    .i_dst_clk(s_aclk),
    .i_signal(m_sresetn),
    .o_signal_sync(m_sreset_sync),
    .o_pulse_sync()
);

/* Full & Empty Flag */
assign full = (wr_ptr_grey == ({~rd_ptr_grey_sync[FIFO_ADDR_WIDTH:FIFO_ADDR_WIDTH-1], rd_ptr_grey_sync[FIFO_ADDR_WIDTH-2:0]}));
assign empty = (rd_ptr_grey == wr_ptr_grey_sync);

/* Writing Logic */

wire [FIFO_ADDR_WIDTH:0] wr_ptr_binary_next = wr_ptr_binary + !full;

always @(posedge s_aclk) begin
    if(!m_sresetn) begin
        wr_ptr_binary <= {FIFO_ADDR_WIDTH{1'b0}};
        wr_ptr_packet_commit <= {FIFO_ADDR_WIDTH{1'b0}};
        wr_ptr_packet_commit_grey <= {FIFO_ADDR_WIDTH{1'b0}};
        wr_ptr_grey <= {FIFO_ADDR_WIDTH{1'b0}};
        s_frame_commit <= 1'b0;
    end else begin
        s_frame_commit <= 1'b0;

        if(s_axis_tvalid & s_axis_trdy) begin
            bram[wr_ptr_binary[FIFO_ADDR_WIDTH-1:0]] <= {s_axis_tdata, s_axis_tlast};
            wr_ptr_binary <= wr_ptr_binary_next; 
            wr_ptr_grey <=  (wr_ptr_binary_next >> 1) ^ wr_ptr_binary_next;         
        end

        //If it is the last packet and it is not a bad packet; udpate the commited pointer
        if(s_axis_tvalid & s_axis_trdy & s_axis_tlast & !s_axis_tuser) begin
            wr_ptr_packet_commit <= wr_ptr_binary_next;
            s_frame_commit <= 1'b1;
        //If the frame was a bad frame, return the write pointer to the last previously commited frame address
        end else if(s_axis_tuser) begin
            wr_ptr_binary <= wr_ptr_packet_commit;
        end
        
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

wire [FIFO_ADDR_WIDTH:0] rd_ptr_binary_next = rd_ptr_binary + !empty;

always @(posedge m_aclk) begin
    if(!m_sresetn) begin
        rd_ptr_binary <= {FIFO_ADDR_WIDTH{1'b0}};
        rd_ptr_grey <= {FIFO_ADDR_WIDTH{1'b0}};        
    end else begin

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
            //Update the read pointer
            rd_ptr_binary <= rd_ptr_binary_next;
            rd_ptr_grey <= (rd_ptr_binary_next >> 1) ^ rd_ptr_binary_next;        
        end
    end
end

/** Pointer Synchronization Logic **/

//Synchronization from read domain into write domain (read -> Write)
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
assign s_axis_trdy = ~full;
assign m_axis_tvalid = m_axis_tvalid_pipe[PIPELINE_STAGES]; 
assign m_axis_tdata = m_axis_tdata_pipe[PIPELINE_STAGES][FIFO_WORD_SIZE-1:1];
assign m_axis_tlast = m_axis_tdata_pipe[PIPELINE_STAGES][0];

endmodule