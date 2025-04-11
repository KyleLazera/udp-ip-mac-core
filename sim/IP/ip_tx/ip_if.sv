
interface ip_if
(
    input bit i_clk,
    input bit i_resetn    
);

    import ip_tx_pkg::*;

   logic ip_tx_hdr_valid;                                       
   logic ip_tx_hdr_rdy;                                        
   logic [7:0]  ip_tx_hdr_type;                                     
   logic [15:0] ip_tx_total_length;                                
   logic [7:0]  ip_tx_protocol;                                  
   logic [31:0] ip_tx_src_ip_addr;                                
   logic [31:0] ip_tx_dst_ip_addr; 

   /* Methods */

    task drive_hdr(ip_tx_hdr_t ip_hdr);
        ip_tx_hdr_valid <= 1'b1;
        ip_tx_hdr_type <= ip_hdr.tos;
        ip_tx_total_length <= ip_hdr.total_length;
        ip_tx_protocol <= ip_hdr.protocol; 
        ip_tx_src_ip_addr <= ip_hdr.src_ip_addr;
        ip_tx_dst_ip_addr <= ip_hdr.dst_ip_addr;
        @(posedge i_clk);
        
        while(!ip_tx_hdr_rdy)
            @(posedge i_clk);

        ip_tx_hdr_valid <= 1'b0;
        
    endtask : drive_hdr

endinterface : ip_if