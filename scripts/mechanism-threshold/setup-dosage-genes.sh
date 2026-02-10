#!/bin/bash
# ============================================================================
# Setup Script for Dosage Genes Table
# ============================================================================
# This script uploads the dosage genes CSV to GCS and creates the external
# table in BigQuery.
#
# Usage:
#   ./setup-dosage-genes.sh [csv_file] [version]
#
# Example:
#   ./setup-dosage-genes.sh "Dosage genes 2.6.26.csv" 2.6.26
# ============================================================================

set -e

# Configuration
PROJECT_ID="clingen-dev"
DATASET="clinvar_ingest"
GCS_BUCKET="clinvar-ingest"
GCS_PATH="mechanism-threshold"

# Parse arguments
CSV_FILE="${1:-Dosage genes 2.6.26.csv}"
VERSION="${2:-2.6.26}"

# Validate CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file '$CSV_FILE' not found."
    echo "Please provide the path to the dosage genes CSV file."
    exit 1
fi

echo "=== Setting up Dosage Genes Table ==="
echo "Project: $PROJECT_ID"
echo "Dataset: $DATASET"
echo "CSV File: $CSV_FILE"
echo "Version: $VERSION"
echo ""

# Step 1: Upload CSV to GCS
echo "Step 1: Uploading CSV to GCS..."
GCS_URI="gs://${GCS_BUCKET}/${GCS_PATH}/dosage_genes_${VERSION}.csv"
gsutil cp "$CSV_FILE" "$GCS_URI"
echo "  Uploaded to: $GCS_URI"

# Step 2: Create or update external table definition
echo ""
echo "Step 2: Creating external table..."

# Create the external table using bq command
bq rm -f "${PROJECT_ID}:${DATASET}.dosage_genes_ext" 2>/dev/null || true

bq mk \
  --external_table_definition="dosage_genes_ext.def" \
  "${PROJECT_ID}:${DATASET}.dosage_genes_ext"

echo "  Created external table: ${PROJECT_ID}:${DATASET}.dosage_genes_ext"

# Step 3: Create the dosage_genes table from the external table
echo ""
echo "Step 3: Creating dosage_genes table from external table..."
bq query --use_legacy_sql=false --project_id="$PROJECT_ID" < 00-setup-dosage-genes.sql

echo ""
echo "=== Setup Complete ==="
echo "The dosage_genes table is now available at: ${PROJECT_ID}:${DATASET}.dosage_genes"
echo ""
echo "To run the analysis:"
echo "  bq query --use_legacy_sql=false --project_id=$PROJECT_ID < 01-mechanism-threshold-analysis.sql"
echo "  bq query --use_legacy_sql=false --project_id=$PROJECT_ID < 02-mechanism-threshold-summary.sql"
