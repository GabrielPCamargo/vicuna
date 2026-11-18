
/**
 * \file util_data_files.c 
 * \brief Benchmark #1.1 random data generation.
 * \author Ivan Rodriguez (BSC)
 */


#include "util_data_files.h"

#include "compression_data.h" // Include the .h file with Input_data and Input_data_len


int load_data_from_file(
    unsigned int *data, 
    unsigned int j_blocksize,
    unsigned int r_samplesInterval,
    unsigned int steps
)
{
    // Verify input parameters match expected values
    if (j_blocksize * r_samplesInterval * steps != Input_data_len * 2) {
        printf("Error: Expected %u samples, but Input_data_len provides %u 32-bit values (%u 16-bit samples)\n",
               j_blocksize * r_samplesInterval * steps, Input_data_len, Input_data_len * 2);
        return FILE_LOADING_ERROR;
    }

    // Unpack 32-bit values into 16-bit samples, zero-extended to 32 bits
    for (unsigned int i = 0; i < Input_data_len; i++) {
        unsigned int word = Input_data_h[i];
        // Extract lower 16 bits (first sample)
        data[2 * i] = word & 0xFFFF;
        // Extract upper 16 bits (second sample)
        data[2 * i + 1] = (word >> 16) & 0xFFFF;
    }

    // Debug: Print first few and block 3171's samples
   
        // printf("First 10 samples:\n");
        // for (int i = 0; i < 10; i++) {
        //     printf("Sample %d: %u\n", i, data[i]);
        // }
        // printf("Block 3171 samples (indices 202752 to 202815):\n");
        // for (int i = 202752; i < 202816; i++) {
        //     printf("Sample %d: %u\n", i, data[i]);
        // }
    
    return FILE_LOADING_SUCCESS;
}


int store_data_to_file(
    char * filename,
    unsigned char *data,
    unsigned int num_elements
    )
{

        FILE *fp;
        fp = fopen(filename, "wb");
        fwrite(data, 1, num_elements, fp); 
        fclose(fp);
        return FILE_LOADING_SUCCESS;
}