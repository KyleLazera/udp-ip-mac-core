
package ip_pkg;

localparam SRC_MAC_ADDR = 48'h10_12_65_23_43_12;
localparam DST_MAC_ADDR = 48'hFF_FF_FF_FF_FF_FF;
localparam ETH_TYPE = 16'h0800;

// IP Header struct
typedef struct {
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
} ip_hdr_t;

// Ethernet Header Struct
typedef struct {
    logic [47:0] src_mac_addr;
    logic [47:0] dst_mac_addr;
    logic [15:0] eth_type;
} eth_hdr_t;

// IP Packet Struct
typedef struct {
    eth_hdr_t eth_hdr;                          // Ethernet Header info passed into the module
    ip_hdr_t ip_hdr;                            // IP Header info passed into the module (in-parallel or part of packet)
    bit[7:0] payload[$];                        // Raw data passed into module
} ip_pckt_t;

class ip_agent;  

    /* Events for Synchornization */
    event tx_pckt_evt;
    event rx_pckt_evt;
    event scb_complete;

    /* Config Variables */
    typedef struct {
        bit version_is_ipv4;
        bit bad_checksum;
    } cfg_ip_agent;

    cfg_ip_agent ip_cfg;

    /* Constructor */
    function new();
        ip_cfg.version_is_ipv4 = 1'b1;
        ip_cfg.bad_checksum = 1'b0;
    endfunction : new

    /* Calculate the IP Header Checksum Value for the specified inputs */
    protected function automatic calculate_checksum(ref ip_pckt_t tx_pckt);
        logic [15:0] words[0:9]; 
        logic [16:0] sum; 
    
        // Form the 16-bit words 
        words[0] = {tx_pckt.ip_hdr.version, tx_pckt.ip_hdr.length, tx_pckt.ip_hdr.tos};                    
        words[1] = tx_pckt.ip_hdr.total_length;
        words[2] = tx_pckt.ip_hdr.ip_hdr_id;
        words[3] = {tx_pckt.ip_hdr.ip_hdr_flags, tx_pckt.ip_hdr.ip_hdr_frag_offset};
        words[4] = {tx_pckt.ip_hdr.ip_hdr_ttl, tx_pckt.ip_hdr.protocol};
        words[5] = 16'h0000; // Placeholder for checksum (set to 0 during calculation)
        words[6] = tx_pckt.ip_hdr.src_ip_addr[31:16];
        words[7] = tx_pckt.ip_hdr.src_ip_addr[15:0];
        words[8] = tx_pckt.ip_hdr.dst_ip_addr[31:16];
        words[9] = tx_pckt.ip_hdr.dst_ip_addr[15:0];    

        // Calculate one's complement sum - If there is a carry out from a sum, add that back to the lsb 
        sum = 0;
        for (int i = 0; i < 10; i++) begin
            sum += words[i];
            if (sum > 16'hFFFF)
                sum = (sum & 16'hFFFF) + 1; 
        end 

        tx_pckt.ip_hdr.ip_hdr_checksum = ~sum[15:0];    
    endfunction : calculate_checksum

    /* Generate raw Payload data */
    protected function void generate_payload(ref bit[7:0] tx_data[$], int payload_size);
        tx_data.delete();
        repeat(payload_size) begin
            tx_data.push_back($urandom_range(0, 255));
        end
    endfunction : generate_payload

    /* Generate data for the IP/Ethernet Header. Certain fields are kept constant */
    protected function automatic generate_header_data(ref ip_pckt_t tx_pckt, int payload_size);

        // Generate the IP Header and checksum
        tx_pckt.ip_hdr.version        = (ip_cfg.version_is_ipv4) ? 4'd4 : 4'd6;  
        tx_pckt.ip_hdr.length         = 4'd5;  
        tx_pckt.ip_hdr.tos            = $urandom();
        tx_pckt.ip_hdr.total_length   = payload_size +  tx_pckt.ip_hdr.length*4;
        tx_pckt.ip_hdr.ip_hdr_id      = 0;
        tx_pckt.ip_hdr.ip_hdr_flags   = 0;
        tx_pckt.ip_hdr.ip_hdr_frag_offset= 0;
        tx_pckt.ip_hdr.ip_hdr_ttl     = 8'd64;      
        tx_pckt.ip_hdr.protocol       = $urandom();
        tx_pckt.ip_hdr.src_ip_addr    = $urandom();
        tx_pckt.ip_hdr.dst_ip_addr    = $urandom();

        // If teh configuration is set to bad checksum, generate a random checksum
        if(ip_cfg.bad_checksum)
            tx_pckt.ip_hdr.ip_hdr_checksum = $urandom();
        else
            calculate_checksum(tx_pckt);

        // Geneate the Ethernet Header Fields
        tx_pckt.eth_hdr.src_mac_addr = SRC_MAC_ADDR;
        tx_pckt.eth_hdr.dst_mac_addr = DST_MAC_ADDR;
        tx_pckt.eth_hdr.eth_type = ETH_TYPE;

    endfunction : generate_header_data 

    /* Creates the IP header and payload */
    function void generate_packet(ref ip_pckt_t tx_pckt);
        int payload_size = $urandom_range(10,1480);
        $display("Payload Size: %0d", payload_size);
        
        //Clear the data queues 
        tx_pckt.payload.delete();
        generate_header_data(tx_pckt, payload_size);
        generate_payload(tx_pckt.payload, payload_size);
    endfunction : generate_packet

    /* Takes IP header and payload and forms an IP packet */
    function void encapsulate_ip_packet(ref ip_pckt_t tx_pckt);
        logic [159:0] ip_hdr;

        // Create IP Header 
        ip_hdr = {
            tx_pckt.ip_hdr.version,
            tx_pckt.ip_hdr.length,
            tx_pckt.ip_hdr.tos,
            tx_pckt.ip_hdr.total_length,
            tx_pckt.ip_hdr.ip_hdr_id,
            tx_pckt.ip_hdr.ip_hdr_flags,
            tx_pckt.ip_hdr.ip_hdr_frag_offset,
            tx_pckt.ip_hdr.ip_hdr_ttl,
            tx_pckt.ip_hdr.protocol,
            tx_pckt.ip_hdr.ip_hdr_checksum,
            tx_pckt.ip_hdr.src_ip_addr,
            tx_pckt.ip_hdr.dst_ip_addr
        };

        // Pre-pend the IP Header to the front of the Payload 
        for(int i = 0; i < 20; i++)
            tx_pckt.payload.push_front(ip_hdr[((i+1)*8)-1 -: 8]); 

    endfunction : encapsulate_ip_packet

    /* De-Encapsulate an IP Frame to isolate the payload*/ 
    function void de_encapsulate_ip_packet(ref ip_pckt_t ip_pckt);
        //Pop off the front 20 bytes of the IP Packet
        for(int i = 0; i < 20; i++)
            ip_pckt.payload.pop_front(); 

    endfunction : de_encapsulate_ip_packet    

    /* Self-checking function to compare the tx and rx packets */
    task self_check(ref ip_pckt_t tx_pckt, ref ip_pckt_t rx_pckt, input bit tx_ip);  

        // Wait for the tx packet to be recieved
        @(tx_pckt_evt);

        // Do not wait for teh RX data event if IP Version is not IPv4
        if(tx_pckt.ip_hdr.version != 4'd4 || ip_cfg.bad_checksum == 1'b1) begin
            $display("Packet Dropped!");
            ->scb_complete;
            return;
        end     

        // Wait for teh RX packet to be recieved
        @(rx_pckt_evt); 

        if(tx_ip) begin
            encapsulate_ip_packet(tx_pckt);
        end 
        // If we are testing the RX IP Module - de-encapsulate the tx data before comparing with the rx_data
        else begin
            de_encapsulate_ip_packet(tx_pckt);
        end
        
        //Ensure the packets are the correct size
        assert(tx_pckt.payload.size() == rx_pckt.payload.size()) 
            else begin
                $display("Tx Packet Size: %0d != Rx Packet Size: %0d MISMATCH", tx_pckt.payload.size(), rx_pckt.payload.size()); 
                $stop;
            end

        // Compare data wihtin packets
        foreach(rx_pckt.payload[i]) begin
            assert(rx_pckt.payload[i] == tx_pckt.payload[i]) 
                else begin 
                    $display("rx_data [%0d] %0h != tx_data [%0d] %0h MISMATCH", i, rx_pckt.payload[i], i, tx_pckt.payload[i]); 
                    $stop; 
                end
        end 

        /* Check Packet Headers */
        assert(tx_pckt.eth_hdr.src_mac_addr == rx_pckt.eth_hdr.src_mac_addr) else $display("Source MAC Address MISMATCH");
        assert(tx_pckt.eth_hdr.dst_mac_addr == rx_pckt.eth_hdr.dst_mac_addr) else $display("Destination MAC Address MISMATCH");
        assert(tx_pckt.eth_hdr.eth_type == rx_pckt.eth_hdr.eth_type) else $display("Ethernet Type MISMATCH");

        ->scb_complete;

    endtask : self_check    

endclass : ip_agent

endpackage : ip_pkg