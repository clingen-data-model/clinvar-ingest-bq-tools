#!/usr/bin/env bash
#
# Usage: ./fetch_gene_pubmed.sh genes.txt 2024/01/01 2025/07/09 > results.tsv

GENE_FILE="$1"
START_DATE="$2"
END_DATE="$3"

# Read the entire gene list into an array
mapfile -t GENES < "$GENE_FILE"

# Print header
echo -e "Gene\tPMID\tURL\tPubDate"

# Iterate over the array (no more STDIN-drain issues)
for GENE in "${GENES[@]}"; do
  # 1) Fetch PMIDs for this gene/date window
  PMIDS=$(esearch \
    -db pubmed \
    -query "${GENE}[TIAB] AND humans[MeSH Terms]" \
    -datetype pdat \
    -mindate "${START_DATE}" \
    -maxdate "${END_DATE}" \
  | efetch -format uid)

  # 2) If we got any, pull dates and emit rows
  if [[ -n "$PMIDS" ]]; then
    while read -r PMID PUBDATE; do
      URL="https://pubmed.ncbi.nlm.nih.gov/${PMID}/"
      echo -e "${GENE}\t${PMID}\t${URL}\t${PUBDATE}"
    done < <(
      esummary -db pubmed -id "${PMIDS}" \
        | xtract -pattern DocumentSummary -element Id,PubDate
    )
  fi
done
