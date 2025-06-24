# To redeploy the gcs-file-ingest-service

Run `./deploy.sh`

wait for the build to complete (make take a few minutes).

once complete

Run `./trigger.sh`

This will delete and recreate the necessary triggers that watch the GCS bucket for file updates.

# To update any of the four files simply upload them to the following bucket

## based on the deploy.sh settings at the time this was written

  `GCS_BUCKET=external-dataset-ingest,BQ_PROJECT=clingen-dev,BQ_DATASET=clinvar_ingest`

## updated files can be sourced from the following locations

  1. organization_summary.txt

    download the file at...
        `https://ftp.ncbi.nlm.nih.gov/pub/clinvar/tab_delimited/organization_summary.txt`

  2. ncbi_gene.txt

    run the script

        `./get-ncbi-gene-txt.sh`

    to download the latest dataset of genes from ncbi and extract only
    the human genes that are NOT of gene type 'biological-region'

  3. hp.json

    downlad the latest hpo terms from...
        `https://hpo.jax.org/data/ontology#:~:text=download-,DOWNLOAD,-LATEST%20HP.JSON`

  4. mondo.json

      download the latest mondo terms from ...
        `https://mondo.monarchinitiative.org/pages/download/#:~:text=json%20edition-,mondo.json,-Equivalent%20to%20the`

### After a new file is copied to the configured GCS bucket...

The following, respective, tables should be updated in BigQuery's clingen-dev project

  1. clinvar-ingest.submitter_organization  (from organization_summary.txt)
  2. clinvar-ingest.ncbi_gene               (from ncbi_gene.txt)
  3. clinvar-ingest.hpo_terms               (from hp.json)
  4. clinvar-ingest.mondo_terms             (from mondo.json)

You can check the table details in BigQuery to verify that the table was updated on a given date.
