#!/usr/bin/env bash

# Add-only update of the gene reference tables used by clinvar_ingest.single_gene_variation,
# from NCBI Gene:
#
#   clinvar_ingest.entrez_gene        human genes with an HGNC-approved symbol and HGNC id
#                                     (Homo_sapiens.gene_info). Used for genes a release's own
#                                     gene table does not list, e.g. genes named in a variant
#                                     title that clinvar does not associate.
#   clinvar_ingest.ncbi_gene_history  human gene ids NCBI has discontinued, with the date
#                                     (gene_history). Lets each release exclude gene ids that
#                                     were already discontinued when it was published.
#
# Neither update changes or removes an existing row, so results computed from earlier
# releases stay reproducible:
#   - entrez_gene: new gene ids are inserted; type_of_gene and description are filled only
#     where still NULL; ids NCBI has retired are kept
#   - ncbi_gene_history: discontinued ids not yet in the table are inserted (NCBI only ever
#     appends to gene_history)
# See docs/methods/single-gene-variation.md for why.
#
# Usage:
#   ./update-gene-reference.sh           # report what would change (no writes to the tables)
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

TARGET="${PROJECT}:${DATASET}.entrez_gene"
STAGE="${PROJECT}:${DATASET}.entrez_gene_stage_${STAMP}"
TARGET_SQL="\`${PROJECT}.${DATASET}.entrez_gene\`"
STAGE_SQL="\`${PROJECT}.${DATASET}.entrez_gene_stage_${STAMP}\`"

HISTORY="${PROJECT}:${DATASET}.ncbi_gene_history"
HISTORY_STAGE="${PROJECT}:${DATASET}.ncbi_gene_history_stage_${STAMP}"
HISTORY_SQL="\`${PROJECT}.${DATASET}.ncbi_gene_history\`"
HISTORY_STAGE_SQL="\`${PROJECT}.${DATASET}.ncbi_gene_history_stage_${STAMP}\`"

APPLY=false
if [ "${1:-}" == "--apply" ]; then
  APPLY=true
fi

WORK="$(mktemp -d)"
cleanup() {
  rm -rf "$WORK"
  bq rm -f -t "$STAGE" >/dev/null 2>&1 || true
  bq rm -f -t "$HISTORY_STAGE" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# ---- entrez_gene ------------------------------------------------------------------------------

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

echo "entrez_gene changes:"
bq query --quiet --nouse_legacy_sql --format=pretty "
  SELECT
    (SELECT COUNT(*) FROM ${STAGE_SQL} s
      WHERE s.has_hgnc AND s.gene_id NOT IN (SELECT gene_id FROM ${TARGET_SQL})) AS genes_to_insert,
    (SELECT ${MISSING_ATTRS} FROM ${TARGET_SQL} e JOIN ${STAGE_SQL} s USING (gene_id)) AS rows_to_fill_type_and_description,
    (SELECT COUNT(*) FROM ${TARGET_SQL} e JOIN ${STAGE_SQL} s USING (gene_id)
      WHERE s.has_hgnc AND (s.symbol_from_authority != e.symbol_from_authority OR s.hgnc_id != e.hgnc_id)) AS changed_at_ncbi_not_applied,
    (SELECT COUNT(*) FROM ${TARGET_SQL} WHERE gene_id NOT IN (SELECT gene_id FROM ${STAGE_SQL})) AS retired_at_ncbi_kept
"

# ---- ncbi_gene_history ------------------------------------------------------------------------

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
  "$HISTORY_STAGE" "$WORK/gene_history.tsv" \
  discontinued_gene_id:STRING,replaced_by_gene_id:STRING,discontinued_symbol:STRING,discontinue_date:DATE
bq update --quiet --expiration 86400 "$HISTORY_STAGE"

if bq show "$HISTORY" >/dev/null 2>&1; then
  echo "ncbi_gene_history changes:"
  bq query --quiet --nouse_legacy_sql --format=pretty "
    SELECT COUNT(*) AS discontinued_ids_to_insert
    FROM ${HISTORY_STAGE_SQL} s
    WHERE s.discontinued_gene_id NOT IN (SELECT discontinued_gene_id FROM ${HISTORY_SQL})
  "
else
  echo "ncbi_gene_history does not exist yet; --apply will create it from the parsed rows."
fi

if [ "$APPLY" != true ]; then
  echo "Report only. Re-run with --apply to back up ${TARGET} and apply these changes."
  exit 0
fi

# ---- apply ------------------------------------------------------------------------------------

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

  CREATE TABLE IF NOT EXISTS ${HISTORY_SQL} (
    discontinued_gene_id STRING NOT NULL OPTIONS (description = 'NCBI gene id that was discontinued'),
    replaced_by_gene_id STRING OPTIONS (description = 'NCBI gene id that replaced it, if any'),
    discontinued_symbol STRING OPTIONS (description = 'symbol of the discontinued gene id'),
    discontinue_date DATE NOT NULL OPTIONS (description = 'date NCBI discontinued the gene id')
  )
  OPTIONS (description = 'Human rows of NCBI gene_history. Add-only; see docs/methods/single-gene-variation.md');

  INSERT INTO ${HISTORY_SQL} (discontinued_gene_id, replaced_by_gene_id, discontinued_symbol, discontinue_date)
  SELECT discontinued_gene_id, NULLIF(replaced_by_gene_id, ''), discontinued_symbol, discontinue_date
  FROM ${HISTORY_STAGE_SQL}
  WHERE discontinued_gene_id NOT IN (SELECT discontinued_gene_id FROM ${HISTORY_SQL});
"

bq query --quiet --nouse_legacy_sql --format=pretty "
  SELECT
    (SELECT COUNT(*) FROM ${TARGET_SQL}) AS entrez_gene_rows,
    (SELECT COUNT(DISTINCT gene_id) FROM ${TARGET_SQL}) AS entrez_gene_distinct_ids,
    (SELECT COUNT(*) FROM ${HISTORY_SQL}) AS ncbi_gene_history_rows
"
echo "Done. entrez_gene backup: ${BACKUP}"
