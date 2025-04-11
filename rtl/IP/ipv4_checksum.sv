
/* The IPv4 header checksum is a simple algorithm that is performed only on 
 * the header of the IP packet. To calculate this checksum, the IP header is 
 * broken down into 10, 16-bit (2 byte) fields. All of the fields are summed
 * together and the ones complement of the result is taken.
 * If there is a carry when summing the fields, it is added back to the lsb 
 * of the result (before the 1's complement is taken).
 */

module ipv4_checksum
(
    input wire i_clk,
    input wire i_reset_n,

    /* IP Header Input - 16 bit fields */
    input wire [15:0] ip_hdr_field,
    input wire ip_checksum_en,

    /* Calculated Checksum */
    output wire [15:0] ip_hdr_checksum                                  
);

reg [16:0] sum = 17'b0;

wire [16:0] initial_sum = ip_hdr_field + sum[15:0];

always @(posedge i_clk) begin
    if(!i_reset_n) begin
        sum <= 17'b0;
    end else begin
        if(ip_checksum_en) begin
            sum <= initial_sum[15:0] + initial_sum[16];
        end else begin
            sum <= 17'b0;
        end
    end
end

assign ip_hdr_checksum = ~sum[15:0];

endmodule : ipv4_checksum