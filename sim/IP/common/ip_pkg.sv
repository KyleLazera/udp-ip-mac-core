
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
    /* Network Packet */
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
        bit version_is_ipv4;            // If true indicates packet version is IPv4
        bit bad_checksum;               // If true, a bad checksum is added to IP header
        bit bad_total_length;           // If true, a bad total length is added
    } cfg_ip_agent;

    cfg_ip_agent ip_cfg;

    /* Constructor */
    function new();
        ip_cfg.version_is_ipv4 = 1'b1;
        ip_cfg.bad_checksum = 1'b0;
        ip_cfg.bad_total_length = 1'b0;
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
        // If bad_total_length is true, intentially make total_length wrong
        tx_pckt.ip_hdr.total_length   = (ip_cfg.bad_total_length) ?  payload_size - 20 : payload_size +  tx_pckt.ip_hdr.length*4;
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
        
        //Clear the data queues 
        tx_pckt.payload.delete();

        // Generate and populate the IP/Ethernet Header for the packet
        generate_header_data(tx_pckt, payload_size);

        // Randomize payload values
        generate_payload(tx_pckt.payload, payload_size);

    endfunction : generate_packet

    /* Takes IP header and payload and forms an IP packet */
    virtual function void encapsulate_ip_packet(ref ip_pckt_t tx_pckt);
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

    function void de_encapsulate_eth_packet(ref ip_pckt_t eth_pckt);
        logic [7:0] rx_byte;

        // Isolate each ethernet header field
        for(int i = 0; i < 14; i++) begin

            rx_byte = eth_pckt.payload.pop_front();

            if(i < 6)
                eth_pckt.eth_hdr.dst_mac_addr = {eth_pckt.eth_hdr.dst_mac_addr[39:0], rx_byte};
            else if(i < 12)
                eth_pckt.eth_hdr.src_mac_addr = {eth_pckt.eth_hdr.src_mac_addr[39:0], rx_byte};
            else
                eth_pckt.eth_hdr.eth_type = {eth_pckt.eth_hdr.eth_type[7:0], rx_byte};
        end
    endfunction : de_encapsulate_eth_packet

    /* De-Encapsulate an IP Frame to isolate the payload*/ 
    function void de_encapsulate_ip_packet(ref ip_pckt_t ip_pckt);
        logic[7:0] tx_byte;

        // Iterate through the payload and isolate each IP header
        for(int i = 0; i < 20; i++) begin

            tx_byte = ip_pckt.payload.pop_front();

            case(i)
                0: begin
                    ip_pckt.ip_hdr.version = tx_byte[7:4];
                    ip_pckt.ip_hdr.length = tx_byte[3:0];
                end
                1: ip_pckt.ip_hdr.tos = tx_byte;
                //2: ip_pckt.ip_hdr.total_length[15:8] = tx_byte;
                //3: ip_pckt.ip_hdr.total_length[7:0] = tx_byte;
                4: ip_pckt.ip_hdr.ip_hdr_id[15:8] = tx_byte;
                5: ip_pckt.ip_hdr.ip_hdr_id[7:0] = tx_byte;
                6: begin
                    ip_pckt.ip_hdr.ip_hdr_flags = tx_byte[7:5];
                    ip_pckt.ip_hdr.ip_hdr_frag_offset[12:8] = tx_byte[4:0];
                end
                7: ip_pckt.ip_hdr.ip_hdr_frag_offset[7:0] = tx_byte;
                8: ip_pckt.ip_hdr.ip_hdr_ttl = tx_byte;
                9: ip_pckt.ip_hdr.protocol = tx_byte;
                //10: ip_pckt.ip_hdr.ip_hdr_checksum[15:8] = tx_byte;
                //11: ip_pckt.ip_hdr.ip_hdr_checksum[7:0] = tx_byte;
                12: ip_pckt.ip_hdr.src_ip_addr[31:24] = tx_byte;
                13: ip_pckt.ip_hdr.src_ip_addr[23:16] = tx_byte;
                14: ip_pckt.ip_hdr.src_ip_addr[15:8] = tx_byte;
                15: ip_pckt.ip_hdr.src_ip_addr[7:0] = tx_byte;
                16: ip_pckt.ip_hdr.dst_ip_addr[31:24] = tx_byte;
                17: ip_pckt.ip_hdr.dst_ip_addr[23:16] = tx_byte;
                18: ip_pckt.ip_hdr.dst_ip_addr[15:8] = tx_byte;
                19: ip_pckt.ip_hdr.dst_ip_addr[7:0] = tx_byte;
            endcase
        end
    endfunction : de_encapsulate_ip_packet

    /* Used to set configuration struct values based on probability to test edge cases */
    function void set_config();
        int prob_not_ipv4 = 0;//($urandom_range(0, 15) == 1);
        int prob_bad_checksum = ($urandom_range(0, 15) == 1);
        int prob_bad_length = 0;//($urandom_range(0, 15) == 1);
        // Using the randomly generated variable, there will be a packet that is not IPv4 or has a bad checksum
        // periodically transmitted to the module
        if(prob_not_ipv4)
            this.ip_cfg.version_is_ipv4 = 1'b0;
        else if(prob_bad_checksum) 
            this.ip_cfg.bad_checksum = 1'b1;
        else if(prob_bad_length)
            this.ip_cfg.bad_total_length = 1'b1;
        else begin
            this.ip_cfg.bad_checksum = 1'b0;
            this.ip_cfg.version_is_ipv4 = 1'b1;
            this.ip_cfg.bad_total_length = 1'b0;
        end
    endfunction : set_config   

    /* Self-checking function to compare the tx and rx packets */
    virtual task self_check(ref ip_pckt_t tx_pckt, ref ip_pckt_t rx_pckt, input bit tx_ip);  

        // Wait for the tx packet to be recieved
        @(tx_pckt_evt);
        // Wait for teh RX packet to be recieved
        @(rx_pckt_evt); 

        if(tx_pckt.ip_hdr.version != 4'd4) begin
            $display("//////////////////////////////////////");
            $display("IP Version != IPv4 - Packet Dropped");
            $display("//////////////////////////////////////");
            ->scb_complete;
            return;
        end 
        else if(ip_cfg.bad_checksum == 1'b1) begin
            $display("//////////////////////////////////////");
            $display("Back Checksum - Packet Dropped");
            $display("//////////////////////////////////////");
            ->scb_complete;
            return;   
        end  
        else if(ip_cfg.bad_total_length == 1'b1) begin
            $display("//////////////////////////////////////");
            $display("Bad Length - Packet Dropped");
            $display("//////////////////////////////////////");
            ->scb_complete;
            return;   
        end 

        if(tx_ip) begin
            encapsulate_ip_packet(tx_pckt);
        end 
        // If we are testing the RX IP Module - de-encapsulate the tx data before comparing with the rx_data
        else begin
            de_encapsulate_ip_packet(tx_pckt);
        end
        
        //Ensure the packets are the correct size
        assert(tx_pckt.payload.size() == rx_pckt.payload.size()) $display("Tx Packet Size: %0d == Rx Packet Size: %0d MATCH", tx_pckt.payload.size(), rx_pckt.payload.size());
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

        // Check Packet Headers 
        assert(tx_pckt.eth_hdr.src_mac_addr == rx_pckt.eth_hdr.src_mac_addr) $display("Source MAC Address MATCH");
            else begin
                $display("Source MAC Address MISMATCH");
                $stop;
            end
        assert(tx_pckt.eth_hdr.dst_mac_addr == rx_pckt.eth_hdr.dst_mac_addr) $display("Source MAC Address MATCH");
            else begin
                $display("Destination MAC Address MISMATCH");
                $stop;
            end
        assert(tx_pckt.eth_hdr.eth_type == rx_pckt.eth_hdr.eth_type) $display("Source MAC Address MATCH");
            else begin
                $display("Ethernet Type MISMATCH");
                $stop;
            end

        ->scb_complete;

    endtask : self_check  

endclass : ip_agent

endpackage : ip_pkg