

/* Virtual interface for writing to the FIFO */

interface wr_if(input clk_wr, input reset_n);
    bit [7:0] data_in;
    bit wr_en;
    bit full;
    
    /* Tasks that define the Bus Interface */
    task push(logic [7:0] data);
        //If the FIFO is full...wait until it is not
        while(full) begin
            wr_en = 1'b0;
            data_in = {(8){1'b0}};
            @(posedge clk_wr);
        end
        
        //If FIFO is not full, raise enable and send data
        wr_en = 1'b1;
        data_in = data;   
    endtask : push
    
endinterface : wr_if

/* Virtual Interface for Reading from the FIFO */

interface rd_if(input clk_rd, input reset_n);
    bit [7:0] data_out;
    bit rd_en;
    bit empty;
    
    /* Task that removes/reads data from FIFO */
    task pop(bit read);
        
        if(read) begin
            //If the FIFO is empty... wait until it is not
            while(empty) begin
                rd_en = 1'b0;
                @(posedge clk_rd);
            end
        
            //If FIFO is not empty, read data from the FIFO
            rd_en = 1'b1;        
        end

    endtask : pop 
      
endinterface : rd_if

