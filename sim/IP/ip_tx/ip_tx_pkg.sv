
package ip_tx_pkg;

// IP Header struct
typedef struct packed {
  bit                  hdr_rdy;
  bit                  hdr_valid;
  logic [15:0]         total_length;
  logic [7:0]          protocol;
  logic [31:0]         src_ip_addr;
  logic [31:0]         dst_ip_addr;
  logic [47:0]         src_mac_addr;
  logic [47:0]         dst_mac_addr;
} ip_tx_hdr_t;

// Input payload & output payload queues
bit [7:0] tx_data[$];
bit [7:0] rx_data[$];

class ip_tx;

// Generate data for the header IP header values
function automatic generate_header_data(ref ip_tx_hdr_t ip_hdr);
    ip_hdr.hdr_valid      = 1'b1;
    ip_hdr.total_length   = $urandom();
    ip_hdr.protocol       = $urandom();
    ip_hdr.src_ip_addr    = $urandom();
    ip_hdr.dst_ip_addr    = $urandom();
    ip_hdr.src_mac_addr   = 48'hFFFFFFFFFFFF; 
    ip_hdr.dst_mac_addr   = 48'h121314151617;
endfunction : generate_header_data   

// Generate raw payload data to encapsulate wihtin an IP frame
function void generate_payload();
    int size = $urandom_range(10, 20);
    repeat(size) begin
        tx_data.push_back($urandom_range(0, 255));
    end
endfunction : generate_payload

function void check();
    // Push the IP header to the front of the apyload and compare the tx_data to the recieved data
endfunction : check

endclass : ip_tx

endpackage : ip_tx_pkg