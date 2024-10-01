#!/bin/bash

# Set your source and destination project IDs (with backticks for hyphenated project names)
DEST_PROJECT="clingen-dev"  # Surround the project with backticks
SOURCE_PROJECT="clingen-stage"  # Surround the project with backticks

# Array of datasets to copy
DATASETS=(
    # "clinvar_2023_02_26_v1_6_57"
    # "clinvar_2023_03_06_v1_6_57"
    # "clinvar_2023_03_11_v1_6_57"
    # "clinvar_2023_03_18_v1_6_57"
    # "clinvar_2023_03_26_v1_6_57"
    # "clinvar_2023_04_04_v1_6_58"
    # "clinvar_2023_04_10_v1_6_58"
    # "clinvar_2023_04_16_v1_6_58"
    # "clinvar_2023_04_24_v1_6_58"
    # "clinvar_2023_04_30_v1_6_58"
    # "clinvar_2023_05_07_v1_6_59"
    # "clinvar_2023_05_14_v1_6_59"
    # "clinvar_2023_05_20_v1_6_60"
    # "clinvar_2023_05_27_v1_6_60"
    # "clinvar_2023_06_04_v1_6_60"
    # "clinvar_2023_06_10_v1_6_60"
    # "clinvar_2023_06_17_v1_6_60"
    # "clinvar_2023_06_26_v1_6_60"
    # "clinvar_2023_07_02_v1_6_60"
    # "clinvar_2023_07_10_v1_6_60"
    # "clinvar_2023_07_17_v1_6_60"
    # "clinvar_2023_07_22_v1_6_60"
    # "clinvar_2023_07_30_v1_6_60"
    # "clinvar_2023_08_06_v1_6_61"
    # "clinvar_2023_08_13_v1_6_61"
    # "clinvar_2023_08_19_v1_6_61"
    # "clinvar_2023_08_26_v1_6_61"
    # "clinvar_2023_09_03_v1_6_61"
    # "clinvar_2023_09_10_v1_6_61"
    # "clinvar_2023_09_17_v1_6_61"
    # "clinvar_2023_09_23_v1_6_61"
    # "clinvar_2023_09_30_v1_6_61"
    # "clinvar_2023_10_07_v1_6_61"
    # "clinvar_2023_10_15_v1_6_61"
    # "clinvar_2023_10_21_v1_6_61"
    # "clinvar_2023_10_28_v1_6_61"
    # "clinvar_2023_11_04_v1_6_61"
    # "clinvar_2023_11_12_v1_6_61"
    # "clinvar_2023_11_21_v1_6_61"
    # "clinvar_2023_11_26_v1_6_61"
    # "clinvar_2023_12_03_v1_6_61"
    # "clinvar_2023_12_09_v1_6_61"
    # "clinvar_2023_12_17_v1_6_61"
    # "clinvar_2023_12_26_v1_6_61"
    # "clinvar_2023_12_30_v1_6_61"
    # "clinvar_2024_01_07_v1_6_61"
    # "clinvar_2024_01_26_v1_6_62"
    # "clinvar_2024_02_06_v1_6_62"
    # "clinvar_2024_02_14_v1_6_62"
    # "clinvar_2024_02_21_v1_6_62"
    # "clinvar_2024_02_29_v1_6_62"
    # "clinvar_2024_03_06_v1_6_62"
    # "clinvar_2024_03_11_v1_6_62"
    # "clinvar_2024_03_17_v1_6_62"
    # "clinvar_2024_03_24_v1_6_62"
    # "clinvar_2024_03_31_v1_6_62"
    # "clinvar_2024_04_07_v1_6_62"
    # "clinvar_2024_04_16_v1_6_62"
    # "clinvar_2024_04_21_v1_6_62"
    # "clinvar_2024_05_02_v1_6_62"
    # "clinvar_2024_05_09_v1_6_62"
    # "clinvar_2024_05_13_v1_6_62"
    # "clinvar_2024_05_19_v1_6_62"
    # "clinvar_2024_05_27_v1_6_62"
    # "clinvar_2024_06_03_v1_6_62"
    # "clinvar_2024_06_11_v1_6_62"
    # "clinvar_2024_06_18_v1_6_62"
    # "clinvar_2024_06_24_v1_6_62"
    # "clinvar_2024_06_30_v1_6_62"
    # "clinvar_2024_07_08_v1_6_62"
    # "clinvar_2024_07_16_v1_6_62"
    # "clinvar_2024_07_24_v1_6_62"
    # "clinvar_2024_07_30_v1_6_62"
    # "clinvar_2024_08_05_v1_6_62"
)

# Function to check if the destination dataset exists, and create it if it doesn't
ensure_dataset_exists() {
    local dataset=$1

    # Check if the dataset exists in the destination project
    bq show --format=prettyjson "${DEST_PROJECT}:${dataset}" > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo "Destination dataset ${DEST_PROJECT}:${dataset} does not exist. Creating it..."
        # Create the destination dataset if it doesn't exist
        bq mk --dataset "${DEST_PROJECT}:${dataset}"

        if [ $? -eq 0 ]; then
            echo "Successfully created dataset: ${DEST_PROJECT}:${dataset}"
        else
            echo "Failed to create dataset: ${DEST_PROJECT}:${dataset}"
            exit 1
        fi
    else
        echo "Dataset ${DEST_PROJECT}:${dataset} already exists."
    fi
}

# Function to copy all tables from a dataset
copy_dataset() {
    local dataset=$1
    echo "Copying dataset: $dataset"

    # Ensure the destination dataset exists before copying tables
    ensure_dataset_exists "$dataset"
    
    # List all tables in the source dataset
    tables=$(bq ls -n 1000 "${SOURCE_PROJECT}:${dataset}" | awk '{print $1}' | tail -n +3)

    # Loop through the tables and copy each one
    for table in $tables; do
      echo "Copying table:  bq cp --location=US ${SOURCE_PROJECT}:${dataset}.${table} ${DEST_PROJECT}:${dataset}.${table}"
      bq cp --location=US "${SOURCE_PROJECT}:${dataset}.${table}" "${DEST_PROJECT}:${dataset}.${table}"
      
      if [ $? -eq 0 ]; then
          echo "Successfully copied table: $table"
      else
          echo "Failed to copy table: $table"
      fi
    done
}

# Loop through the list of datasets and copy each one
for dataset in "${DATASETS[@]}"; do
    copy_dataset "$dataset"
done

echo "Dataset copy process completed."