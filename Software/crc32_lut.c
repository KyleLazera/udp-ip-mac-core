
/**
 * Algorithm used to populate the CRC32 LUT based of the byte values ranging from 0 to 255. This algorithm prints out the
 * LUT to a .txt file, which is then used in Vivado to initialize the ROM .The algorithm is as follows:
 * 
 * 1) Shift the input byte to the left so it is 32 bits in length and teh MSB matches with the MSB of the CRC polynomial.
 * 2) If the MSb of the input byte is 1, shift it to the left by 1 and then XOR with the generator polynomial.
 * 3) If the MSb of the input byte is not 1, then just shift the value left by 1.
 * 4) Reapt step 2 and 3 for each bit in the byte.
 * 5) Store this value in the LUT at the index that corresponds to the original input byte.
 * 
 * The CRC-32 Generator Polynomial used for ethernet is:
 * x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x^1 + 1 or 0x04C11DB7
 */

#include <stdint.h>
#include <stdio.h>

/* Macros used in program*/
#define CRC_POLY    0x04C11DB7
#define BITS_8      8
#define BITS_32     32


/**
 * @brief Print the LUT values in a .txt file sequentially 
 * @note This is used in Vivado to initialize the CRC32 LUT
 * @param file_ptr The pointer for the file
 * @param lut The generated Look-up table
 */
void display_LUT(FILE* file_ptr, uint32_t lut[]);

/**
 * @brief Converts the value to 32 bits and prints this value out to the file
 * @param num The value to display on the file
 * @param file the file ptr  
 */
void convert_to_bits(uint32_t num, FILE* file);

int main()
{
    FILE *crc_lut_file;
    uint32_t crc_table[256];           //CRC table to store the Calculated values

    //Open the file to write into 
    crc_lut_file = fopen("CRC_LUT.txt", "w");

    //Error checking for file init
    if(crc_lut_file == NULL)
    {
        printf("Error opening file!\n");
        return 1;
    }

    //Algorithm to generate CRC32 values based on all possible byte values (0 - 255)
    for(uint32_t i_byte = 0; i_byte < 256; i_byte++)
    {
        uint32_t crc_byte = 0;
        crc_byte = crc_byte ^ (i_byte << 24);

        //printf("Input Byte: %d", i_byte);

        //To calculate the CRC for each byte, we have to iterate through each bit 
        for(uint8_t i_bits = 0; i_bits < 8; i_bits++)
        {
            //Check if the most significant bit of the byte is a 1
            if((crc_byte & 0x80000000) != 0)
                crc_byte = (crc_byte << 1) ^ CRC_POLY;            
            
            else
                crc_byte = (crc_byte << 1);            
        }    

        //Store value in LUT
        crc_table[i_byte] = crc_byte;

    }

    //Function used to print the LUT to a .txt file
    display_LUT(crc_lut_file, crc_table);

    // Close the file after writing
    fclose(crc_lut_file);

    return 0;
}


void convert_to_bits(uint32_t num, FILE* file)
{
    for(int i = 31; i >= 0; i--){
        //print each bit at a time
        fprintf(file, "%d", (num >> i) & 1);
    }
    
    fprintf(file, "\n");
}

void display_LUT(FILE* file_ptr, uint32_t lut[])
{
    //Iterate through the LUT and print each value to the .txt file 
    for(int i = 0; i < 256; i++){
        convert_to_bits(lut[i], file_ptr);
    }
}
