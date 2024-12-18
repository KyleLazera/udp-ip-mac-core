

/* Virtual interface for writing to the FIFO */

interface wr_if(input clk_wr, input reset_n);
    bit [7:0] data_in;
    bit wr_en;
    bit almost_full;
    bit full;
    
    /* Tasks that define the Bus Interface */
    task push(logic [7:0] data, bit write);      
        
        if(write) begin
            wr_en <= 1'b1;
            data_in <= data;
        end         
        
        @(posedge clk_wr);        
        wr_en <= 1'b0; 
        
    endtask : push
    
endinterface : wr_if

/* Virtual Interface for Reading from the FIFO */

interface rd_if(input clk_rd, input reset_n);
    bit [7:0] data_out;
    bit rd_en;
    bit almost_empty;
    bit empty;
    
    /* Task that pop data from FIFO */
    task pop(bit read);
        @(posedge clk_rd);
        
        if(read) 
            rd_en <= 1'b1;        
        else
            rd_en <= 1'b0;
    endtask : pop 
    
    /* Task used to read the output data from the FIFO */
    task read_data(output [7:0] data);
        
        data = data_out;        
    endtask : read_data
      
endinterface : rd_if

