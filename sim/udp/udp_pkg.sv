
package udp_pkg;

typedef struct{
    logic [15:0] src_port;
    logic [15:0] dst_port;
    logic [15:0] udp_length;
    logic [15:0] udp_checksum;
    bit [7:0] udp_payload[$];
}udp_pkt_t;

class udp_agent;

    event scb_complete;

    // Generates values for the UDP header - checksum is currently set to 0
    virtual protected function void gen_udp_hdr(ref udp_pkt_t udp_pckt);
        udp_pckt.src_port = $urandom();
        udp_pckt.dst_port = $urandom();
        udp_pckt.udp_checksum = 16'b0;
        udp_pckt.udp_length = 16'd8;
    endfunction : gen_udp_hdr

    // Generate bytes to populate the UDP payload
    protected function void gen_payload(ref bit[7:0] payload[$], int payload_size);
        repeat(payload_size) begin
            payload.push_back($urandom_range(0, 255));
        end
    endfunction : gen_payload

    // Seperates the UDP packet into UDP header and UDP payload
    virtual function void de_encap_udp_hdr(ref udp_pkt_t rx_pckt);

        for(int i = 0; i < 8; i++) begin
            case(i)
                0: rx_pckt.src_port[15:8] = rx_pckt.udp_payload.pop_front();
                1: rx_pckt.src_port[7:0] = rx_pckt.udp_payload.pop_front();
                2: rx_pckt.dst_port[15:8] = rx_pckt.udp_payload.pop_front();
                3: rx_pckt.dst_port[7:0] = rx_pckt.udp_payload.pop_front();    
                4: rx_pckt.udp_length[15:8] = rx_pckt.udp_payload.pop_front();
                5: rx_pckt.udp_length[7:0] = rx_pckt.udp_payload.pop_front();
                6: rx_pckt.udp_checksum[15:8] = rx_pckt.udp_payload.pop_front();
                7: rx_pckt.udp_checksum[7:0] = rx_pckt.udp_payload.pop_front();
            endcase
        end
    endfunction : de_encap_udp_hdr

    function void encap_udp_data(ref udp_pkt_t tx_pckt);
        logic [63:0] udp_hdr;

        // Create UDP Header
        udp_hdr = {
            tx_pckt.src_port,
            tx_pckt.dst_port,
            tx_pckt.udp_length,
            tx_pckt.udp_checksum
        };

        // Pre-pend the header to the payload
        for(int i = 0; i < 8; i++) begin
            tx_pckt.udp_payload.push_front(udp_hdr[((i+1)*8)-1 -: 8]);
        end

    endfunction : encap_udp_data

    virtual function void gen_udp_pkt(ref udp_pkt_t tx_pkt);
        int payload_size = $urandom_range(10, 20); 
        
        gen_udp_hdr(tx_pkt);
        gen_payload(tx_pkt.udp_payload, payload_size);
    endfunction : gen_udp_pkt

    virtual function void self_check(ref udp_pkt_t tx_pckt, ref udp_pkt_t rx_pckt);

        // Compare Each UDP header field from teh tx and px packets
        assert(tx_pckt.src_port == rx_pckt.src_port)
            else begin
                $display("TX Src port %0h != RX Src port %0h MISMATCH!", tx_pckt.src_port, rx_pckt.src_port);
                $finish;
            end

        assert(tx_pckt.dst_port == rx_pckt.dst_port)
            else begin
                $display("TX Dst port %0h != RX Dst port %0h MISMATCH!", tx_pckt.dst_port, rx_pckt.dst_port);
                $finish;
            end

        // Once all header fields are compared, compare the size of the payload and teh values in it
        assert(tx_pckt.udp_payload.size() == rx_pckt.udp_payload.size())
            else begin
                $display("TX payload size port %0h != RX payload size port %0h MISMATCH!", tx_pckt.udp_payload.size(), rx_pckt.udp_payload.size());
                $finish;
            end

        // Make sure the UDP size field is correct
        assert(rx_pckt.udp_length == tx_pckt.udp_length)
            else begin
                $display("RX UDP Length Field %0h != TX UDP Length Field %0h", rx_pckt.udp_length, tx_pckt.udp_length);
                $finish;
            end

        foreach(tx_pckt.udp_payload[i])
            assert(tx_pckt.udp_payload[i] == rx_pckt.udp_payload[i])
                else begin
                    $display("TX data [%0d] %0h != RX data [%0d] %0h MISMATCH!", i, tx_pckt.udp_payload[i], i, rx_pckt.udp_payload[i]);
                    $finish;
                end

        rx_pckt.udp_payload.delete();
        tx_pckt.udp_payload.delete();

        ->scb_complete;

    endfunction : self_check

endclass : udp_agent


class udp_top_agent extends udp_agent;

    logic [31:0] src_ip_addr;
    logic [31:0] dst_ip_addr;
    logic [7:0] ip_protocol = 8'h11;

    // Generates values for the UDP header - checksum is currently set to 0
    protected function void gen_udp_hdr(ref udp_pkt_t udp_pckt);
        src_ip_addr = $urandom();
        dst_ip_addr = $urandom();
        udp_pckt.src_port = $urandom();
        udp_pckt.dst_port = $urandom();
        udp_pckt.udp_checksum = 16'b0;
        udp_pckt.udp_length = 16'd8;
    endfunction : gen_udp_hdr

    function void gen_udp_pkt(ref udp_pkt_t tx_pkt);
        int payload_size = $urandom_range(10, 1472); 
        
        gen_udp_hdr(tx_pkt);
        gen_payload(tx_pkt.udp_payload, payload_size);
    endfunction : gen_udp_pkt

    function logic [15:0] calculate_checksum(udp_pkt_t tx_pckt);
        logic [15:0] hdr_words[0:7]; 
        logic [16:0] sum = 0; 
        int udp_pckt_size = (tx_pckt.udp_payload.size()+8);
        
        //Separate the IP pseudo-header + UDP Header into 16 bit fields
        hdr_words[0] = src_ip_addr[31:16];
        hdr_words[1] = src_ip_addr[15:0];
        hdr_words[2] = dst_ip_addr[31:16];
        hdr_words[3] = dst_ip_addr[15:0];
        hdr_words[4] = {8'h00, ip_protocol};
        hdr_words[5] = tx_pckt.src_port;
        hdr_words[6] = tx_pckt.dst_port;
        hdr_words[7] = udp_pckt_size;


        // Iterate through and add the headers to calculate the final checksum value
        for (int i = 0; i < 8; i++) begin
            sum += hdr_words[i];
            if (sum > 16'hFFFF)
                sum = (sum & 16'hFFFF) + 1; 
        end 

        //Iterate through the payload, passing 16 bit field values into the calculation
        for (int i = 0; i < udp_pckt_size; i += 2) begin
            logic [15:0] word;

            // If the payload size is odd, padd a 00 at the end 
            if (i+1 < udp_pckt_size)
                word = {tx_pckt.udp_payload[i], tx_pckt.udp_payload[i+1]};
            else
                word = {tx_pckt.udp_payload[i], 8'h00}; 

            sum += word;
            if (sum > 16'hFFFF)
                sum = (sum & 16'hFFFF) + 1;

        end

        // Take the ones complement of the output
        calculate_checksum = ~sum[15:0];
    endfunction : calculate_checksum

    // Seperates the UDP packet into UDP header and UDP payload
    function void de_encap_udp_hdr(ref udp_pkt_t rx_pckt);

        for(int i = 0; i < 8; i++) begin
            case(i)
                0: rx_pckt.src_port[15:8] = rx_pckt.udp_payload.pop_front();
                1: rx_pckt.src_port[7:0] = rx_pckt.udp_payload.pop_front();
                2: rx_pckt.dst_port[15:8] = rx_pckt.udp_payload.pop_front();
                3: rx_pckt.dst_port[7:0] = rx_pckt.udp_payload.pop_front();  
                default: rx_pckt.udp_payload.pop_front();  
            endcase
        end
    endfunction : de_encap_udp_hdr

    function void self_check(ref udp_pkt_t tx_pckt, ref udp_pkt_t rx_pckt);

        logic [15:0] reference_checksum = calculate_checksum(tx_pckt);

        // Compare Each UDP header field from teh tx and px packets
        assert(tx_pckt.src_port == rx_pckt.src_port)
            else begin
                $display("TX Src port %0h != RX Src port %0h MISMATCH!", tx_pckt.src_port, rx_pckt.src_port);
                $finish;
            end

        assert(tx_pckt.dst_port == rx_pckt.dst_port)
            else begin
                $display("TX Dst port %0h != RX Dst port %0h MISMATCH!", tx_pckt.dst_port, rx_pckt.dst_port);
                $finish;
            end

        // Ensure the UDP length is the correct size
        assert(rx_pckt.udp_length == (rx_pckt.udp_payload.size() + 8))
            else begin
                $display("RX UDP Length %0d != Actual Length %0d MISMATCH!", rx_pckt.udp_length, (rx_pckt.udp_payload.size() + 8));
                $finish;
            end

        // Make sure the calculated checksum is correct
        assert(rx_pckt.udp_checksum == reference_checksum)
            else begin
                $display("RX Checksum %0h != Reference Checksum %0h MISMATCH!", rx_pckt.udp_checksum, reference_checksum);
                $finish;
            end

        // Once all header fields are compared, compare the size of the payload and teh values in it
        assert(tx_pckt.udp_payload.size() == rx_pckt.udp_payload.size())
            else begin
                $display("TX payload size port %0h != RX payload size port %0h MISMATCH!", tx_pckt.udp_payload.size(), rx_pckt.udp_payload.size());
                $finish;
            end

        // Make sure the UDP size field is correct
        assert(rx_pckt.udp_length == (rx_pckt.udp_payload.size() + 8))
            else begin
                $display("RX UDP Length Field %0d != Actual udp payload length %0d", rx_pckt.udp_length, (rx_pckt.udp_payload.size() + 8));
                $finish;
            end

        foreach(tx_pckt.udp_payload[i])
            assert(tx_pckt.udp_payload[i] == rx_pckt.udp_payload[i])
                else begin
                    $display("TX data [%0d] %0h != RX data [%0d] %0h MISMATCH!", i, tx_pckt.udp_payload[i], i, rx_pckt.udp_payload[i]);
                    $finish;
                end

        rx_pckt.udp_payload.delete();
        tx_pckt.udp_payload.delete();

        ->scb_complete;
    endfunction : self_check


endclass : udp_top_agent

endpackage : udp_pkg