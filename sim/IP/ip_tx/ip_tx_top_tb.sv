`include "../../common/axi_stream_rx_bfm.sv"
`include "../../common/axi_stream_tx_bfm.sv"

module ip_tx_top;

// Clock & Reset Signals
bit clk_100;
bit reset_n;

// IP Header struct
typedef struct packed {
  bit                  hdr_valid;
  bit                  hdr_rdy;
  logic [15:0]         total_length;
  logic [7:0]          protocol;
  logic [31:0]         src_ip_addr;
  logic [31:0]         dst_ip_addr;
  logic [47:0]         src_mac_addr;
  logic [47:0]         dst_mac_addr;
} ip_tx_hdr_t;

//instantiate IP header & payload
ip_tx_hdr_t ip_hdr;
bit [7:0] payload[$];
bit [7:0] rx_data[$];

// AXI Stream Interface Declarations
axi_stream_tx_bfm axi_tx(.s_aclk(clk_100), .s_sresetn(reset_n));
axi_stream_rx_bfm axi_rx(.m_aclk(clk_100), .m_sresetn(reset_n));

always #5 clk_100 = ~clk_100;

//Initialize Clock and reset values
initial begin 
    clk_100 = 1'b0;
    reset_n = 1'b0;
    #100;
    reset_n = 1'b1;
end

/* DUT Instantantiation */
ipv4_tx #(
    .AXI_STREAM_WIDTH(8)
) ip_tx (
   .i_clk(clk_100),
   .i_reset_n(reset_n),
   .s_tx_axis_tdata(axi_tx.s_axis_tdata),                 
   .s_tx_axis_tvalid(axi_tx.s_axis_tvalid),                 
   .s_tx_axis_tlast(axi_tx.s_axis_tlast),                  
   .s_tx_axis_trdy(axi_tx.s_axis_trdy),                   
   .ip_tx_hdr_valid(ip_hdr.hdr_valid),                  
   .ip_tx_hdr_rdy(ip_hdr.hdr_rdy),                     
   .ip_tx_total_length(ip_hdr.total_length),              
   .ip_tx_protocol(ip_hdr.protocol),                 
   .ip_tx_src_ip_addr(ip_hdr.src_ip_addr),             
   .ip_tx_dst_ip_addr(ip_hdr.dst_ip_addr),              
   .ip_tx_src_mac_addr(ip_hdr.src_mac_addr),             
   .ip_tx_dst_mac_addr(ip_hdr.dst_mac_addr),               
   .m_tx_axis_tdata(axi_rx.m_axis_tdata),                 
   .m_tx_axis_tvalid(axi_rx.m_axis_tvalid),                
   .m_tx_axis_tlast(axi_rx.m_axis_tlast),                  
   .m_tx_axis_trdy(axi_rx.m_axis_trdy) 
);

// Generate data on the header IP values
function automatic generate_header_data(ref ip_tx_hdr_t ip_hdr);
    ip_hdr.hdr_valid      = 1'b1;
    ip_hdr.total_length   = $urandom();
    ip_hdr.protocol       = $urandom();
    ip_hdr.src_ip_addr    = $urandom();
    ip_hdr.dst_ip_addr    = $urandom();
    ip_hdr.src_mac_addr   = 48'hFFFFFFFFFFFF; 
    ip_hdr.dst_mac_addr   = 48'h121314151617;
endfunction : generate_header_data    

function void generate_payload();
    int size = $urandom_range(10, 20);

    repeat(size) begin
        payload.push_back($urandom_range(0, 255));
    end
endfunction : generate_payload

initial begin
    axi_tx.s_axis_tdata = 1'b0;
    axi_tx.s_axis_tvalid = 1'b0;
    axi_tx.s_axis_tlast = 1'b0;
    axi_rx.m_axis_trdy = 1'b1;

    //Wait for reset to be asserted
    @(posedge reset_n);

    //Drive IP values on the DUT
    generate_header_data(ip_hdr);
    generate_payload();

    fork
        begin axi_tx.axis_transmit_basic(payload); end
        begin axi_rx.axis_read(rx_data); end
    join

    #1000;

    $finish;

end

endmodule : ip_tx_top