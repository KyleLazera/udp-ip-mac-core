

package network_stack;

localparam SRC_IP_ADDR = 32'h10_00_00_00;

localparam ETH_PREAMBLE = 8'h55;
localparam ETH_SFD = 8'hd5;
localparam SRC_MAC_ADDR = 48'hDEADBEEF000A;
localparam DST_MAC_ADDR = 48'hCAFEBABE00BB;
localparam ETH_TYPE = 16'h0800;
localparam IP_PROTOCL = 8'h11;

// Ethernet Header Data Structure
typedef struct {
    logic [47:0] src_mac_addr;
    logic [47:0] dst_mac_addr;
    logic [15:0] eth_type;
} eth_hdr_t;

// Ip Header Data Structure 
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

// Network Package Data Structure 
typedef struct{
    eth_hdr_t   eth_hdr;
    ip_hdr_t    ip_hdr;
    bit [7:0]   payload[$];
} pckt_t;

// L2 (Ethernet) class used to create ethernet packets
class eth_mac;

    /*Parameters */
    localparam DATA_WIDTH = 8;
    localparam CRC_WIDTH = 32;
    localparam TABLE_DEPTH = (2**DATA_WIDTH);
    localparam PADDING = 8'h00;
    localparam MIN_BYTES = 60;
    localparam HDR = 8'h55;
    localparam SFD = 8'hD5; 
    typedef logic [7:0] data_packet[$]; 

    /* Variables */
    bit [CRC_WIDTH-1:0] crc_lut [TABLE_DEPTH-1:0];       

    function new();
        $readmemb("/home/klazera/Projects/1gbs_ethernet_mac/Software/CRC_LUT.txt", crc_lut);
    endfunction : new

    //Fnction that calculates the crc32 for the input data
    function automatic [31:0] crc32_reference_model;
        input [7:0] i_byte_stream[];
        
        /* Intermediary Signals */
        reg [31:0] crc_state = 32'hFFFFFFFF;
        reg [31:0] crc_state_rev;
        reg [7:0] i_byte_rev, table_index;
        integer i;
        
        //Iterate through each byte in the stream
        foreach(i_byte_stream[i]) begin
             /* Reverse the bit order of the byte in question */
             i_byte_rev = 0;
             for(int j = 0; j < 8; j++)
                i_byte_rev[j] = i_byte_stream[i][(DATA_WIDTH-1)-j];
                
             /* XOR this value with the MSB of teh current CRC State */
             table_index = i_byte_rev ^ crc_state[31:24];
             
             /* Index into the LUT and XOR the output with the shifted CRC */
             crc_state = {crc_state[24:0], 8'h0} ^ crc_lut[table_index];
        end
        
        /* Reverse & Invert the final CRC State after all bytes have been iterated through */
        crc_state_rev = 32'h0;
        for(int k = 0; k < 32; k++) 
            crc_state_rev[k] = crc_state[(CRC_WIDTH-1)-k];
        
        crc32_reference_model = ~crc_state_rev;
        
    endfunction : crc32_reference_model 

    function void pad_packet(ref bit [7:0] driver_data[$]);
        int packet_size;
        
        //Reverse the endianess byte-wise
        driver_data =  {<<8{driver_data}};
        
        packet_size = driver_data.size();

        //If the packet had less than 60 bytes, we need to pad it
        while(packet_size < MIN_BYTES) begin
            driver_data.push_back(PADDING);
            packet_size++;
        end
    endfunction : pad_packet
    
    //Function that encapsulates teh data into an etehrnet frame
    function void encapsulate_data(ref bit [7:0] driver_data[$]);
        
        //int packet_size;
        logic [31:0] crc;

        pad_packet(driver_data);

        //Calculate the CRC for the Payload & append to the back
        crc = crc32_reference_model(driver_data);

        for(int i = 0; i < 4; i++) begin
            driver_data.push_back(crc[i*8 +: 8]);
        end

        //Prepend the header & SFD
        for(int i = 7; i >= 0; i--) begin    
            if(i == 7)
                driver_data.push_front(SFD);
            else
                driver_data.push_front(HDR);
        end         
                

    endfunction : encapsulate_data 

endclass : eth_mac

// L3 Class that inherits for ethernet mac class (L2)
class ip_stack extends eth_mac;

    event check_complete;

    /* Calculate the IP Header Checksum Value for the specified inputs */
    protected function automatic calculate_ip_checksum(ref pckt_t tx_pckt);
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
    endfunction : calculate_ip_checksum

    /* Generate data for the IP/Ethernet Header. Certain fields are kept constant */
    protected function automatic generate_ip_header(ref pckt_t tx_pckt, int payload_size);

        // Generate the IP Header and checksum
        tx_pckt.ip_hdr.version        = 4'd4; 
        tx_pckt.ip_hdr.length         = 4'd5;  
        tx_pckt.ip_hdr.tos            = 8'h00;
        tx_pckt.ip_hdr.total_length   = payload_size + tx_pckt.ip_hdr.length*4;
        tx_pckt.ip_hdr.ip_hdr_id      = 0;
        tx_pckt.ip_hdr.ip_hdr_flags   = 0;
        tx_pckt.ip_hdr.ip_hdr_frag_offset= 0;
        tx_pckt.ip_hdr.ip_hdr_ttl     = 8'd64;      
        tx_pckt.ip_hdr.protocol       = IP_PROTOCL;
        tx_pckt.ip_hdr.src_ip_addr    = $urandom();
        tx_pckt.ip_hdr.dst_ip_addr    = SRC_IP_ADDR;

        calculate_ip_checksum(tx_pckt);

        // Geneate the Ethernet Header Fields
        tx_pckt.eth_hdr.src_mac_addr = DST_MAC_ADDR;
        tx_pckt.eth_hdr.dst_mac_addr = SRC_MAC_ADDR;
        tx_pckt.eth_hdr.eth_type = ETH_TYPE;

        $display("IP Header Breakdown:");
        $display("Total Length: %0d", tx_pckt.ip_hdr.total_length);
        $display("SRC IP Address (From external device): %0h", tx_pckt.ip_hdr.src_ip_addr);

    endfunction : generate_ip_header 

    /* Generate raw Payload data */
    protected function void generate_payload(ref bit[7:0] tx_data[$], int payload_size);
        tx_data.delete();
        repeat(payload_size) begin
            tx_data.push_back($urandom_range(0, 255));
        end
    endfunction : generate_payload

    /* Encapsulated the payload with IP header + ethernet addresses + etehrnet type */
    protected function void encap_ip_packet(ref pckt_t tx_pckt);
        logic [159:0] ip_hdr;
        logic [111:0] eth_hdr;

        //Encapslate the IP within the ethernet packet
        eth_hdr = {
            tx_pckt.eth_hdr.dst_mac_addr,
            tx_pckt.eth_hdr.src_mac_addr,
            tx_pckt.eth_hdr.eth_type
        };

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

        // Encapsulate within the IP Header
        for(int i = 0; i < 20; i++)
            tx_pckt.payload.push_back(ip_hdr[((i+1)*8)-1 -: 8]); 

        // Encapsulate within the Ethernet Header
        for(int i = 0; i < 14; i++) 
            tx_pckt.payload.push_back(eth_hdr[((i+1)*8)-1 -: 8]);

    endfunction : encap_ip_packet

    // This function is used for self checking and does 2 things:
    // 1) Remove the ethernet header info from the payload field
    // 2) Compare the ethernet header information between 2 packets
    protected function void de_encap_ethernet(ref pckt_t tx_pckt, ref pckt_t rx_pckt);
        logic [47:0] tx_src_mac_addr, tx_dst_mac_addr;
        logic [47:0] rx_src_mac_addr, rx_dst_mac_addr;
        logic [15:0] tx_eth_type, rx_eth_type;
        logic [31:0] tx_crc32, rx_crc32;

        /* Preamble Check */

        // Check & remove the ethernet preamble 
        for(int i=0; i < 8; i++) begin

            // If it is the 7th byte, compare with the start frame delimiter (8'D5)
            if(i == 7) begin 
                assert(tx_pckt.payload.pop_front() == ETH_SFD) else
                    $display("Ethernet SFD MISTMATCH");

                assert(rx_pckt.payload.pop_front() == ETH_SFD) else
                    $display("Ethernet SFD MISTMATCH");
            end else begin
                assert(tx_pckt.payload.pop_front() == ETH_PREAMBLE) else
                    $display("Ethernet Preamble MISTMATCH");

                assert(rx_pckt.payload.pop_front() == ETH_PREAMBLE) else
                    $display("Ethernet Preamble MISTMATCH");
            end

        end

        /* CRC32 Check */

        // Remove the CRC32 from the end of both payloads & store it in a variable for comparison
        repeat(4) begin
            tx_crc32 = {tx_crc32[24:0], tx_pckt.payload.pop_back()};
            rx_crc32 = {rx_crc32[24:0], rx_pckt.payload.pop_back()};
        end

        // Pass the payload into the CRC compuation function to compute the CRC32 & compare the values
        assert(tx_crc32 == crc32_reference_model(tx_pckt.payload))
            else begin
                $display("Tx expected CRC32 %0h != tx recieved CRC32 %0h", crc32_reference_model(tx_pckt.payload), tx_crc32);
                $finish;
            end

        assert(rx_crc32 == crc32_reference_model(rx_pckt.payload))
            else begin
                $display("Rx expected CRC32 %0h != Rx recieved CRC32 %0h", crc32_reference_model(rx_pckt.payload), rx_crc32);
                $finish;
            end

        /* Isolate MAC Addresses & Ethernet Type */

        // Isolate the Src/Dst MAC addresses and ethernet type of each packet
        repeat(6) begin
            logic [7:0] tx_byte; 
            logic [7:0] rx_byte; 

            tx_byte = tx_pckt.payload.pop_front();
            rx_byte = rx_pckt.payload.pop_front();

            tx_dst_mac_addr = {tx_dst_mac_addr[39:0], tx_byte};
            rx_dst_mac_addr = {rx_dst_mac_addr[39:0], rx_byte};
        end

        repeat(6) begin
            logic [7:0] tx_byte; 
            logic [7:0] rx_byte; 

            tx_byte = tx_pckt.payload.pop_front();
            rx_byte = rx_pckt.payload.pop_front();

            tx_src_mac_addr = {tx_src_mac_addr[39:0], tx_byte};
            rx_src_mac_addr = {rx_src_mac_addr[39:0], rx_byte};
        end

        tx_pckt.eth_hdr.src_mac_addr = tx_src_mac_addr;
        //$display("TX SRC MAC ADDR: %0h", tx_pckt.eth_hdr.src_mac_addr);
        tx_pckt.eth_hdr.dst_mac_addr = tx_dst_mac_addr;
        //$display("TX DST MAC ADDR: %0h", tx_pckt.eth_hdr.dst_mac_addr);

        rx_pckt.eth_hdr.src_mac_addr = rx_src_mac_addr;
        //$display("RX SRC MAC ADDR: %0h", rx_pckt.eth_hdr.src_mac_addr);
        rx_pckt.eth_hdr.dst_mac_addr = rx_dst_mac_addr;
        //$display("RX DST MAC ADDR: %0h", rx_pckt.eth_hdr.dst_mac_addr);

        // Isolate the Ethernet Type
        repeat(2) begin
            tx_eth_type = {tx_eth_type, tx_pckt.payload.pop_front()};
            rx_eth_type = {rx_eth_type, rx_pckt.payload.pop_front()};
        end

        tx_pckt.eth_hdr.eth_type = tx_eth_type;
        rx_pckt.eth_hdr.eth_type = rx_eth_type;

    endfunction : de_encap_ethernet

    // This function is used in teh self checking and separates the IP header fields from the 
    // payload to check them
    protected function void de_encap_ip(ref pckt_t tx_pckt, ref pckt_t rx_pckt);
        logic[7:0] tx_byte, rx_byte;

        // Iterate through the payload and grab each IP header
        for(int i = 0; i < 20; i++) begin

            tx_byte = tx_pckt.payload.pop_front();
            rx_byte = rx_pckt.payload.pop_front();

            case(i)
                0: begin
                    tx_pckt.ip_hdr.version = tx_byte[7:4];
                    tx_pckt.ip_hdr.length = tx_byte[3:0];

                    rx_pckt.ip_hdr.version = rx_byte[7:4];
                    rx_pckt.ip_hdr.length = rx_byte[3:0];

                    assert(tx_pckt.ip_hdr.version == rx_pckt.ip_hdr.version) 
                        else begin
                            $display("IP tx Version %0h != IP rx Version %0h MISMATCH", tx_pckt.ip_hdr.version, rx_pckt.ip_hdr.version);
                            $finish;
                        end

                    assert(tx_pckt.ip_hdr.length == rx_pckt.ip_hdr.length) 
                        else begin
                            $display("IP tx Length %0h != IP rx Length %0h MISMATCH", tx_pckt.ip_hdr.length, rx_pckt.ip_hdr.length);
                        $finish;
                        end
                end
                1: begin
                    tx_pckt.ip_hdr.tos = tx_byte;
                    rx_pckt.ip_hdr.tos = rx_byte;

                    assert(tx_pckt.ip_hdr.tos == rx_pckt.ip_hdr.tos) 
                        else begin
                            $display("IP tx TOS %0h != IP rx TOS %0h MISMATCH", tx_pckt.ip_hdr.tos, rx_pckt.ip_hdr.tos);
                            $finish;
                        end
                end
                2: begin
                    tx_pckt.ip_hdr.total_length[15:8] = tx_byte;
                    rx_pckt.ip_hdr.total_length[15:8] = rx_byte;
                end
                3: begin
                    tx_pckt.ip_hdr.total_length[7:0] = tx_byte;
                    rx_pckt.ip_hdr.total_length[7:0] = rx_byte;

                    assert(tx_pckt.ip_hdr.total_length == rx_pckt.ip_hdr.total_length) 
                        else begin
                            $display("IP tx Total Length %0h != IP rx Total Length %0h MISMATCH", tx_pckt.ip_hdr.total_length, rx_pckt.ip_hdr.total_length);
                            $finish;
                        end
                end
                4: begin
                    tx_pckt.ip_hdr.ip_hdr_id[15:8] = tx_byte;
                    rx_pckt.ip_hdr.ip_hdr_id[15:8] = rx_byte;
                end
                5: begin
                    tx_pckt.ip_hdr.ip_hdr_id[7:0] = tx_byte;
                    rx_pckt.ip_hdr.ip_hdr_id[7:0] = rx_byte;

                    assert(tx_pckt.ip_hdr.ip_hdr_id == rx_pckt.ip_hdr.ip_hdr_id) 
                        else begin
                            $display("IP tx Header ID %0h != IP rx Header ID %0h MISMATCH", tx_pckt.ip_hdr.ip_hdr_id, rx_pckt.ip_hdr.ip_hdr_id);
                            $finish;
                        end
                end
                6: begin
                    tx_pckt.ip_hdr.ip_hdr_flags = tx_byte[7:5];
                    rx_pckt.ip_hdr.ip_hdr_flags = rx_byte[7:5];

                    assert(tx_pckt.ip_hdr.ip_hdr_flags == rx_pckt.ip_hdr.ip_hdr_flags) 
                        else begin
                            $display("IP tx IP Header Flag %0h != IP rx IP Header Flag %0h MISMATCH", tx_pckt.ip_hdr.ip_hdr_flags, rx_pckt.ip_hdr.ip_hdr_flags);
                            $finish;
                        end

                    tx_pckt.ip_hdr.ip_hdr_frag_offset[12:8] = tx_byte[4:0];
                    rx_pckt.ip_hdr.ip_hdr_frag_offset[12:8] = rx_byte[4:0];
                end
                7: begin
                    tx_pckt.ip_hdr.ip_hdr_frag_offset[7:0] = tx_byte;
                    rx_pckt.ip_hdr.ip_hdr_frag_offset[7:0] = rx_byte;

                    assert(tx_pckt.ip_hdr.ip_hdr_frag_offset == rx_pckt.ip_hdr.ip_hdr_frag_offset) 
                        else begin
                            $display("IP tx Fragment offset %0h != IP rx Fragment offset %0h MISMATCH", tx_pckt.ip_hdr.ip_hdr_frag_offset, rx_pckt.ip_hdr.ip_hdr_frag_offset);
                            $finish;
                        end
                end
                8: begin
                    tx_pckt.ip_hdr.ip_hdr_ttl = tx_byte;
                    rx_pckt.ip_hdr.ip_hdr_ttl = rx_byte;

                    assert(tx_pckt.ip_hdr.ip_hdr_ttl == rx_pckt.ip_hdr.ip_hdr_ttl) 
                        else begin 
                            $display("IP tx TTL %0h != IP rx TTL %0h MISMATCH", tx_pckt.ip_hdr.ip_hdr_ttl, rx_pckt.ip_hdr.ip_hdr_ttl);
                            $finish;
                        end
                end
                9: begin
                    tx_pckt.ip_hdr.protocol = tx_byte;
                    rx_pckt.ip_hdr.protocol = rx_byte;

                    assert(tx_pckt.ip_hdr.protocol == rx_pckt.ip_hdr.protocol) 
                        else begin
                            $display("IP tx protocol %0h != IP rx protocol %0h MISMATCH", tx_pckt.ip_hdr.protocol, rx_pckt.ip_hdr.protocol);
                            $finish;
                        end

                end
                10: begin
                    tx_pckt.ip_hdr.ip_hdr_checksum[15:8] = tx_byte;
                    rx_pckt.ip_hdr.ip_hdr_checksum[15:8] = rx_byte;
                end
                11: begin
                    tx_pckt.ip_hdr.ip_hdr_checksum[7:0] = tx_byte;
                    rx_pckt.ip_hdr.ip_hdr_checksum[7:0] = rx_byte;
                end
                12: begin
                    tx_pckt.ip_hdr.src_ip_addr[31:24] = tx_byte;
                    rx_pckt.ip_hdr.src_ip_addr[31:24] = rx_byte;
                end
                13: begin
                    tx_pckt.ip_hdr.src_ip_addr[23:16] = tx_byte;
                    rx_pckt.ip_hdr.src_ip_addr[23:16] = rx_byte;
                end
                14: begin
                    tx_pckt.ip_hdr.src_ip_addr[15:8] = tx_byte;
                    rx_pckt.ip_hdr.src_ip_addr[15:8] = rx_byte;
                end
                15: begin
                    tx_pckt.ip_hdr.src_ip_addr[7:0] = tx_byte;
                    rx_pckt.ip_hdr.src_ip_addr[7:0] = rx_byte;
                end
                16: begin
                    tx_pckt.ip_hdr.dst_ip_addr[31:24] = tx_byte;
                    rx_pckt.ip_hdr.dst_ip_addr[31:24] = rx_byte;
                end
                17: begin
                    tx_pckt.ip_hdr.dst_ip_addr[23:16] = tx_byte;
                    rx_pckt.ip_hdr.dst_ip_addr[23:16] = rx_byte;
                end
                18: begin
                    tx_pckt.ip_hdr.dst_ip_addr[15:8] = tx_byte;
                    rx_pckt.ip_hdr.dst_ip_addr[15:8] = rx_byte;
                end
                19: begin
                    tx_pckt.ip_hdr.dst_ip_addr[7:0] = tx_byte;
                    rx_pckt.ip_hdr.dst_ip_addr[7:0] = rx_byte;
                end
            endcase
        end
        
    endfunction : de_encap_ip

    // This will generate an IP packet, encapsulated with ethernet headers + CRC32
    function void generate_packet(ref pckt_t tx_pckt);
        int payload_size = $urandom_range(10, 1480); 

        // Create an IP packet that is encapsulated with ethernet mac addresses & ethernet type
        generate_payload(tx_pckt.payload, payload_size);
        generate_ip_header(tx_pckt, payload_size);
        encap_ip_packet(tx_pckt);

        // Add the ethernet preamble + CRC32 to the packet
        encapsulate_data(tx_pckt.payload);

    endfunction : generate_packet

    function void check_data(pckt_t tx_pckt, pckt_t rx_pckt);

        de_encap_ethernet(tx_pckt, rx_pckt);
        de_encap_ip(tx_pckt, rx_pckt);

        //Check the payload size
        assert(tx_pckt.payload.size() == rx_pckt.payload.size()) $display("TX Packet Size  %0d == RX Packet Size %0d MATCH", tx_pckt.payload.size(), rx_pckt.payload.size());
        else begin
            $display("TX Packet Size  %0d != RX Packet Size %0d MISMATCH", tx_pckt.payload.size(), rx_pckt.payload.size());
            $finish;
        end

        ///////////////////////////////////////////////////////////////////////
        // Check the Ethernet Header Matches. Due to the loopback, the src MAC 
        // for the tx packet should be equivelent to the dst MAC for rx packet 
        // and vice versa. The ethernet type should be equivelent for both.
        ///////////////////////////////////////////////////////////////////////

        assert(tx_pckt.eth_hdr.dst_mac_addr == rx_pckt.eth_hdr.src_mac_addr) 
            else begin
                $display("Dst MAC for TX packet: %0h != Src MAC for RX packet: %0h MISMATCH", tx_pckt.eth_hdr.dst_mac_addr, rx_pckt.eth_hdr.src_mac_addr);
                $finish;
            end

        assert(tx_pckt.eth_hdr.src_mac_addr == rx_pckt.eth_hdr.dst_mac_addr) 
            else begin
                $display("Src MAC for TX packet: %0h != Dst MAC for RX packet: %0h MISMATCH", tx_pckt.eth_hdr.src_mac_addr, rx_pckt.eth_hdr.dst_mac_addr);
                $finish;
            end

        assert(tx_pckt.eth_hdr.eth_type == rx_pckt.eth_hdr.eth_type) 
            else begin
                $display("Eth Type for TX packet: %0h != Eth Type for RX packet: %0h MISMATCH", tx_pckt.eth_hdr.eth_type, rx_pckt.eth_hdr.eth_type);
                $finish;
            end

        ///////////////////////////////////////////////////////////////////////
        // Check each field of the IP header. All fields should be equivelent 
        // except for the src IP address & destination IP address. Similarly to
        // the ethernet comparison, due to the loopback from teh top module, the 
        // src IP from the tx packet should be equievelent to the dst IP of the 
        // rx packet and vice versa. All the fields that are supposed to match 
        // are checked in the de_encap_ip function as they are removed from the 
        // payload.
        ///////////////////////////////////////////////////////////////////////

        assert(tx_pckt.ip_hdr.src_ip_addr == rx_pckt.ip_hdr.dst_ip_addr) 
            else begin 
                $display("SRC IP for TX packet %0h != DST IP for RX packet %0h", tx_pckt.ip_hdr.src_ip_addr, rx_pckt.ip_hdr.dst_ip_addr);
                $finish;
            end

        assert(tx_pckt.ip_hdr.dst_ip_addr == rx_pckt.ip_hdr.src_ip_addr) 
            else begin 
                $display("DST IP for TX packet %0h != SRC IP for RX packet %0h", tx_pckt.ip_hdr.dst_ip_addr, rx_pckt.ip_hdr.src_ip_addr);
                $finish;
            end

        // If the ethernet fields and the IP fields were correct, check the remainder of the payload
        foreach(tx_pckt.payload[i]) 
            assert(tx_pckt.payload[i] == rx_pckt.payload[i])
            else begin
                $display("TX Payload [%0d] %0h != RX Payload [%0d] %0h", i, tx_pckt.payload[i], i, rx_pckt.payload[i]);
                $finish;
            end

        // Clear both payloads
        tx_pckt.payload.delete();
        rx_pckt.payload.delete();

        // Signal the event
        ->check_complete;

    endfunction : check_data

endclass : ip_stack

endpackage : network_stack