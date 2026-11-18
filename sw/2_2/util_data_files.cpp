/**
 * \file util_data_files.c 
 * \brief Benchmark #2.2 random data generation.
 * \author Ivan Rodriguez (BSC)
 */


#include "util_data_files.h"


#include "compression_data.h" // Include the .h file with Input_data and Input_data_len

int load_data_from_file(
    compression_image_data_t *ccsds_data
)
{
    // Validate input parameters
    if (ccsds_data->bit_size != 16) {
        printf("Error: Only bit_size = 16 is supported for .h file input\n");
        return FILE_LOADING_ERROR;
    }
    if (ccsds_data->h_size * ccsds_data->w_size != Input_data_len) {
        printf("Error: Expected %u samples (h_size * w_size), but Input_data_len provides %u 32-bit values (%u 16-bit samples)\n",
               ccsds_data->h_size * ccsds_data->w_size, Input_data_len, Input_data_len);
        return FILE_LOADING_ERROR;
    }

    // Unpack 32-bit values into 16-bit samples, zero-extended to 32 bits
    for (unsigned int i = 0; i < Input_data_len; i++) {
        // Little-endian: Lower 16 bits first
        ccsds_data->input_image[i] = Input_data_h[i];
    }

    // // Debug: Print samples for block 3171 (indices 202752 to 202815)
    // printf("Block 3171 samples (indices 202752 to 202815):\n");
    // for (unsigned int i = ccsds_data->h_size * ccsds_data->w_size - 100; i < ccsds_data->h_size * ccsds_data->w_size; i++) {
    //     printf("Sample %u: 0x%08x\n", i, ccsds_data->input_image[i]);
    // }

    // Apply padding if needed
    if (ccsds_data->pad_rows != 0 || ccsds_data->pad_columns != 0) {
        // Pad rows: Copy last row to padded rows
        for (unsigned int i = 0; i < ccsds_data->pad_rows; i++) {
            for (unsigned int j = 0; j < ccsds_data->w_size + ccsds_data->pad_columns; j++) {
                ccsds_data->input_image[(i + ccsds_data->h_size) * (ccsds_data->w_size + ccsds_data->pad_columns) + j] =
                    ccsds_data->input_image[(ccsds_data->h_size - 1) * ccsds_data->w_size + j];
            }
        }

        // Pad columns: Copy last column to padded columns
        for (unsigned int i = 0; i < ccsds_data->pad_columns; i++) {
            for (unsigned int j = 0; j < ccsds_data->h_size + ccsds_data->pad_rows; j++) {
                ccsds_data->input_image[j * (ccsds_data->w_size + ccsds_data->pad_columns) + (i + ccsds_data->w_size)] =
                    ccsds_data->input_image[j * ccsds_data->w_size + (ccsds_data->w_size - 1)];
            }
        }
    }

    return FILE_LOADING_SUCCESS;
}


int store_data_to_file(
    char * filename,
    compression_image_data_t * ccdsd_data
    )
{
 return FILE_STORAGE_SUCCESS;   
}