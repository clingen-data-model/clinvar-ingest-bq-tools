#!/usr/bin/env bash

# Add-only update of clinvar_ingest.entrez_gene from NCBI Gene (human gene_info).
#
# entrez_gene is the gene reference used by clinvar_ingest.single_gene_variation.
# It holds human NCBI genes that have an HGNC-approved symbol and HGNC id.
#
# This script never changes or removes an existing row's id, symbol or HGNC id,
# so results computed from earlier releases stay reproducible:
#   - gene ids not yet in the table are inserted
#   - type_of_gene and description are filled only where they are still NULL
#   - gene ids that NCBI has retired are kept
# See docs/methods/single-gene-variation.md for why.
#
# Usage:
#   ./update-entrez-gene.sh           # report what would change (no writes)
#   ./update-entrez-gene.sh --apply   # back up the table, then apply the changes
#
# Environment:
#   BQ_PROJECT (default clingen-dev), BQ_DATASET (default clinvar_ingest)

set -euo pipefail

PROJECT="${BQ_PROJECT:-clingen-dev}"
DATASET="${BQ_DATASET:-clinvar_ingest}"
NCBI_URL="https://ftp.ncbi.nih.gov/gene/DATA/GENE_INFO/Mammalia/Homo_sapiens.gene_info.gz"
STAMP="$(date +%Y%m%d)"
TARGET="${PROJECT}:${DATASET}.entrez_gene"
STAGE="${PROJECT}:${DATASET}.entrez_gene_stage_${STAMP}"
TARGET_SQL="\`${PROJECT}.${DATASET}.entrez_gene\`"
STAGE_SQL="\`${PROJECT}.${DATASET}.entrez_gene_stage_${STAMP}\`"

APPLY=false
if [ "${1:-}" == "--apply" ]; then
  APPLY=true
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Downloading ${NCBI_URL} ..."
curl -sSf -o "$WORK/gene_info.gz" "$NCBI_URL"

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

bq load --quiet --replace --source_format=CSV --field_delimiter=tab --quote='' \
  "$STAGE" "$WORK/entrez_gene.tsv" \
  gene_id:STRING,symbol_from_authority:STRING,symbol:STRING,hgnc_id:STRING,type_of_gene:STRING,description:STRING,has_hgnc:BOOL
bq update --quiet --expiration 86400 "$STAGE"

HAS_ATTR_COLUMNS="$(bq show --schema --format=json "$TARGET" | grep -c '"type_of_gene"' || true)"
if [ "$HAS_ATTR_COLUMNS" -gt 0 ]; then
  MISSING_ATTRS="COUNTIF(e.type_of_gene IS NULL OR e.description IS NULL)"
else
  MISSING_ATTRS="COUNT(*)"
fi

echo "Changes:"
bq query --quiet --nouse_legacy_sql --format=pretty "
  SELECT
    (SELECT COUNT(*) FROM ${STAGE_SQL} s
      WHERE s.has_hgnc AND s.gene_id NOT IN (SELECT gene_id FROM ${TARGET_SQL})) AS genes_to_insert,
    (SELECT ${MISSING_ATTRS} FROM ${TARGET_SQL} e JOIN ${STAGE_SQL} s USING (gene_id)) AS rows_to_fill_type_and_description,
    (SELECT COUNT(*) FROM ${TARGET_SQL} e JOIN ${STAGE_SQL} s USING (gene_id)
      WHERE s.has_hgnc AND (s.symbol_from_authority != e.symbol_from_authority OR s.hgnc_id != e.hgnc_id)) AS changed_at_ncbi_not_applied,
    (SELECT COUNT(*) FROM ${TARGET_SQL} WHERE gene_id NOT IN (SELECT gene_id FROM ${STAGE_SQL})) AS retired_at_ncbi_kept
"

if [ "$APPLY" != true ]; then
  echo "Report only. Re-run with --apply to back up ${TARGET} and apply these changes."
  bq rm -f -t "$STAGE"
  exit 0
fi

BACKUP="${PROJECT}:${DATASET}.entrez_gene_bak_${STAMP}"
echo "Backing up ${TARGET} to ${BACKUP} ..."
bq cp --quiet -n "$TARGET" "$BACKUP"

echo "Applying ..."
bq query --quiet --nouse_legacy_sql "
  ALTER TABLE ${TARGET_SQL}
    ADD COLUMN IF NOT EXISTS type_of_gene STRING OPTIONS (description = 'NCBI gene_info type_of_gene'),
    ADD COLUMN IF NOT EXISTS description STRING OPTIONS (description = 'NCBI gene_info description');

  INSERT INTO ${TARGET_SQL} (gene_id, symbol_from_authority, symbol, hgnc_id, type_of_gene, description)
  SELECT gene_id, symbol_from_authority, symbol, hgnc_id, type_of_gene, description
  FROM ${STAGE_SQL}
  WHERE has_hgnc AND gene_id NOT IN (SELECT gene_id FROM ${TARGET_SQL});

  UPDATE ${TARGET_SQL} e
  SET
    type_of_gene = IFNULL(e.type_of_gene, s.type_of_gene),
    description = IFNULL(e.description, s.description)
  FROM ${STAGE_SQL} s
  WHERE s.gene_id = e.gene_id AND (e.type_of_gene IS NULL OR e.description IS NULL);
"

bq rm -f -t "$STAGE"
bq query --quiet --nouse_legacy_sql --format=pretty "
  SELECT COUNT(*) AS row_count, COUNT(DISTINCT gene_id) AS distinct_gene_ids, COUNTIF(type_of_gene IS NULL) AS no_ncbi_record
  FROM ${TARGET_SQL}
"
echo "Done. Backup: ${BACKUP}"
