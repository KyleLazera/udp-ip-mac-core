
package ip_pkg;

// IP Header struct
typedef struct packed {
  bit                  hdr_rdy;
  bit                  hdr_valid;
  logic [3:0]          version;
  logic [3:0]          length;
  logic [7:0]          tos;
  logic [15:0]         total_length;
  logic [15:0]         ip_hdr_id;
  logic [2:0]          ip_hdr_flags;
  logic [12:0]         ip_hdr_frag_offset;
  logic [7:0]          ip_hdr_ttl;  
  logic [7:0]          protocol;
  logic [15:0]         ip_hdr_checksum;
  logic [31:0]         src_ip_addr;
  logic [31:0]         dst_ip_addr;
} ip_tx_hdr_t;

// Ethernet Header Struct
typedef struct packed {
    logic [47:0] src_mac_addr;
    logic [47:0] dst_mac_addr;
    logic [15:0] eth_type;
} eth_hdr_t;

// Input payload & output payload queues
bit [7:0] tx_data[$];
bit [7:0] rx_data[$];

class ip;

    protected int payload_size = 0;

    function new();
        this.payload_size = $urandom_range(10, 1480);
    endfunction : new

    /* Protected Mehtods */

    /* Calculate the IP Header Checksum Value for the specified inputs */
    protected function automatic calculate_checksum(ref ip_tx_hdr_t ip_hdr);
        logic [15:0] words[0:9]; 
        logic [16:0] sum; 
    
        // Form the 16-bit words 
        words[0] = {ip_hdr.version, ip_hdr.length, ip_hdr.tos};                    
        words[1] = ip_hdr.total_length;
        words[2] = ip_hdr.ip_hdr_id;
        words[3] = {ip_hdr.ip_hdr_flags, ip_hdr.ip_hdr_frag_offset};
        words[4] = {ip_hdr.ip_hdr_ttl, ip_hdr.protocol};
        words[5] = 16'h0000; // Placeholder for checksum (set to 0 during calculation)
        words[6] = ip_hdr.src_ip_addr[31:16];
        words[7] = ip_hdr.src_ip_addr[15:0];
        words[8] = ip_hdr.dst_ip_addr[31:16];
        words[9] = ip_hdr.dst_ip_addr[15:0];    

        // Calculate one's complement sum - If there is a carry out from a sum, add that back to the lsb 
        sum = 0;
        for (int i = 0; i < 10; i++) begin
            sum += words[i];
            if (sum > 16'hFFFF)
                sum = (sum & 16'hFFFF) + 1; 
        end 

        ip_hdr.ip_hdr_checksum = ~sum[15:0];    
    endfunction : calculate_checksum

    protected function void encapsulate_ip_packet(ip_tx_hdr_t ip_hdr);
        logic [159:0] ip_hdr;

        /* Create IP Header */
        ip_hdr = {
            ip_hdr.version,
            ip_hdr.length,
            ip_hdr.tos,
            ip_hdr.total_length,
            ip_hdr.ip_hdr_id,
            ip_hdr.ip_hdr_flags,
            ip_hdr.ip_hdr_frag_offset,
            ip_hdr.ip_hdr_ttl,
            ip_hdr.protocol,
            ip_hdr.ip_hdr_checksum,
            ip_hdr.src_ip_addr,
            ip_hdr.dst_ip_addr
        };
        
        /* Pre-pend the IP Header to the front of the Payload */
        for(int i = 0; i < 20; i++)
            tx_data.push_front(ip_hdr[((i+1)*8)-1 -: 8]); 

    endfunction : encapsulate_ip_packet

    /* De-Encapsulate an IP Frame */
    protected function void de_encapsulate_ip_packet();
        //Pop off the front 20 bytes of the IP Packet
        for(int i = 0; i < 20; i++)
            tx_data.pop_front(); 

    endfunction : de_encapsulate_ip_packet

    /* Public Methods */

    /* Generate data for the IP Header. Certain fields are kept constant */
    function automatic generate_header_data(ref ip_tx_hdr_t ip_hdr);
        ip_hdr.hdr_valid      = 1'b1;
        ip_hdr.version        = 4'd4;   //IPv4
        ip_hdr.length         = 4'd5;  
        ip_hdr.tos            = $urandom();
        ip_hdr.total_length   = payload_size + ip_hdr.length*4;
        ip_hdr.ip_hdr_id      = 0;
        ip_hdr.ip_hdr_flags   = 0;
        ip_hdr.ip_hdr_frag_offset= 0;
        ip_hdr.ip_hdr_ttl     = 8'd64;      
        ip_hdr.protocol       = $urandom();
        ip_hdr.src_ip_addr    = $urandom();
        ip_hdr.dst_ip_addr    = $urandom();

        calculate_checksum(ip_hdr);

    endfunction : generate_header_data 

    /* Generate raw payload data to encapsulate wihtin an IP frame */
    function void generate_payload();
        //payload_size = $urandom_range(10, 20);
        tx_data.delete();
        repeat(payload_size) begin
            tx_data.push_back($urandom_range(0, 255));
        end
    endfunction : generate_payload

    /* Generate a full IP packet */
    function automatic generate_ip_packet(ref ip_tx_hdr_t ip_hdr);
        
        // Create payload and IP Header & encapsulate it
        generate_payload();
        generate_header_data(ip_hdr);        
        encapsulate_ip_packet(ip_hdr);

    endfunction : generate_ip_packet

    // Self-checking function to compare the tx and rx packets 
    function void check(ip_tx_hdr_t ip_hdr, bit tx_ip);

        // If we are comparing in tx mode, we need to encapsulate the tx data (raw payload) & compare
        // it with the rx data. If we are checking the rx ip, we need to de-encapsulate the output packet
        // before comparing it.
        if(tx_ip) begin
            encapsulate_ip_packet(ip_hdr);
        end else
            de_encapsulate_ip_packet();

        //Ensure the packets are the correct size
        assert(tx_data.size() == rx_data.size()) 
            else begin
                $display("Tx Packet Size: %0d != Rx Packet Size: %0d MISMATCH", tx_data.size(), rx_data.size()); 
                $stop;
            end

        // Compare data wihtin packets
        foreach(rx_data[i]) begin
            assert(rx_data[i] == tx_data[i]) //$display("rx_data: %0h == tx_data %0h MATCH", rx_data[i], tx_data[i]);
                else begin 
                    $display("rx_data [%0d] %0h != tx_data [%0d] %0h MISMATCH", i, rx_data[i], i, tx_data[i]); 
                    $stop; 
                end
        end  

        //Clear packet for next iteration
        rx_data.delete();
    endfunction : check

endclass : ip

endpackage : ip_pkg