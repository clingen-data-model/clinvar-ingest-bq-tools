#!/bin/bash


# Define the array
mmyy_array=(
    # '2023-01' 
    # '2023-02' 
    # '2023-03' 
    # '2023-04' 
    # '2023-05' 
    # '2023-06' 
    # '2023-07' 
    # '2023-08' 
    # '2023-09' 
    # '2023-10' 
    # '2023-11' 
    # '2023-12' 
    # '2024-01' 
    # '2024-02',
    # '2024-03',
    # '2024-04',
    # '2024-05',
    # '2024-06'
)

# Loop through each value in the array
for mmyy in "${mmyy_array[@]}"; do
    echo "Processing $mmyy..."

    bq load \
        --replace \
        --source_format=CSV \
        clinvar_000.${mmyy}-rcv-source \
        "gs://clinvar-ingest-dev/rcv-old/${mmyy}/rcv_clinvarset_recs_part*"

    # Check if the command succeeded
    if [ $? -ne 0 ]; then
        echo "Error processing $mmyy. Exiting."
        exit 1
    fi

    echo "$mmyy processed successfully."
done

echo "All tasks completed."

# original version
# bq load \
#   --replace \
#   --source_format=CSV \
#   clinvar_000.2023-07-rcv-source \
#   "gs://clinvar-ingest-dev/rcv-old/2023-07/rcv_clinvarset_recs_part*"