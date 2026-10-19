#!/usr/bin/env bash

# Add-only update of the gene reference tables used by clinvar_ingest.single_gene_variation,
# from NCBI Gene. This is the manual equivalent of the step the clinvar-ingest
# stored-procedures job runs at the start of every run.
#
#   clinvar_ingest.entrez_gene        human genes with an HGNC-approved symbol and HGNC id
#                                     (Homo_sapiens.gene_info). Used for genes a release's own
#                                     gene table does not list, e.g. genes named in a variant
#                                     title that clinvar does not associate.
#   clinvar_ingest.ncbi_gene_history  human gene ids NCBI has discontinued, with the date
#                                     (gene_history). Lets each release exclude gene ids that
#                                     were already discontinued when it was published.
#
# The script downloads and parses the two files into staging tables, then calls the stored
# procedure clinvar_ingest.gene_reference_update (scripts/general/gene-reference-update-proc.sql),
# which applies the add-only changes and logs the run to clinvar_ingest.gene_reference_refresh_log.
# validate_dataset fails a release when no refresh is logged on or after its release date.
# See docs/methods/single-gene-variation.md.
#
# Usage:
#   ./update-gene-reference.sh           # report what would change (no changes to the tables)
#   ./update-gene-reference.sh --apply   # back up entrez_gene, then apply the changes
#
# Environment:
#   BQ_PROJECT (default clingen-dev), BQ_DATASET (default clinvar_ingest)

set -euo pipefail

PROJECT="${BQ_PROJECT:-clingen-dev}"
DATASET="${BQ_DATASET:-clinvar_ingest}"
GENE_INFO_URL="https://ftp.ncbi.nih.gov/gene/DATA/GENE_INFO/Mammalia/Homo_sapiens.gene_info.gz"
GENE_HISTORY_URL="https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz"
STAMP="$(date +%Y%m%d)"

APPLY=false
if [ "${1:-}" == "--apply" ]; then
  APPLY=true
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Downloading ${GENE_INFO_URL} ..."
curl -sSf -o "$WORK/gene_info.gz" "$GENE_INFO_URL"

# gene_info columns: 2 GeneID, 3 Symbol, 6 dbXrefs, 9 description, 10 type_of_gene,
#                    11 Symbol_from_nomenclature_authority
# has_hgnc is true when the gene has an HGNC symbol and an HGNC id; only those are inserted.
gunzip -c "$WORK/gene_info.gz" \
  | awk -F'\t' 'BEGIN { OFS = "\t" }
    NR > 1 && $1 == "9606" {
      hgnc = ""
      n = split($6, refs, "|")
      for (i = 1; i <= n; i++) {
        if (refs[i] ~ /^HGNC:HGNC:/) { sub(/^HGNC:/, "", refs[i]); hgnc = refs[i] }
      }
      has_hgnc = ($11 != "-" && hgnc != "") ? "true" : "false"
      print $2, ($11 == "-" ? "" : $11), $3, hgnc, $10, $9, has_hgnc
    }' \
  > "$WORK/entrez_gene.tsv"
echo "Parsed $(wc -l < "$WORK/entrez_gene.tsv" | tr -d ' ') human genes"

echo "Downloading ${GENE_HISTORY_URL} ..."
curl -sSf -o "$WORK/gene_history.gz" "$GENE_HISTORY_URL"

# gene_history columns: 1 tax_id, 2 GeneID (replacement, or "-"), 3 Discontinued_GeneID,
#                       4 Discontinued_Symbol, 5 Discontinue_Date (YYYYMMDD)
gunzip -c "$WORK/gene_history.gz" \
  | awk -F'\t' 'BEGIN { OFS = "\t" }
    $1 == "9606" {
      print $3, ($2 == "-" ? "" : $2), $4, substr($5, 1, 4) "-" substr($5, 5, 2) "-" substr($5, 7, 2)
    }' \
  > "$WORK/gene_history.tsv"
echo "Parsed $(wc -l < "$WORK/gene_history.tsv" | tr -d ' ') human discontinued gene ids"

bq load --quiet --replace --source_format=CSV --field_delimiter=tab --quote='' \
  "${PROJECT}:${DATASET}.entrez_gene_stage" "$WORK/entrez_gene.tsv" \
  gene_id:STRING,symbol_from_authority:STRING,symbol:STRING,hgnc_id:STRING,type_of_gene:STRING,description:STRING,has_hgnc:BOOL
bq load --quiet --replace --source_format=CSV --field_delimiter=tab --quote='' \
  "${PROJECT}:${DATASET}.ncbi_gene_history_stage" "$WORK/gene_history.tsv" \
  discontinued_gene_id:STRING,replaced_by_gene_id:STRING,discontinued_symbol:STRING,discontinue_date:DATE

if [ "$APPLY" == true ]; then
  BACKUP="${PROJECT}:${DATASET}.entrez_gene_bak_${STAMP}"
  echo "Backing up entrez_gene to ${BACKUP} ..."
  bq cp --quiet -f "${PROJECT}:${DATASET}.entrez_gene" "$BACKUP"
  bq update --quiet --expiration 2592000 "$BACKUP"
fi

bq query --quiet --nouse_legacy_sql --format=pretty \
  "CALL \`${PROJECT}.${DATASET}.gene_reference_update\`(${APPLY}, 'update-gene-reference.sh')"

if [ "$APPLY" != true ]; then
  echo "Report only. Re-run with --apply to apply these changes."
fi
