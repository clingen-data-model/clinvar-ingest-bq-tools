#!/usr/bin/env bash

# Change to the data directory for all file operations
cd "$(dirname "$0")/../data" || exit 1

# Download and extract only the desired fields + OMIM IDs
# 1) download the full gene info file from ncbi
#    (this is a large file, ~1.5GB compressed, ~6GB uncompressed)
# wget ftp://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz    # ftp site with README & data

# 2) total lines (for progress calculation)
total=$(gunzip -c gene_info.gz | wc -l)

# 3) stream, filter, extract + progress → ncbi_gene.txt
gunzip -c gene_info.gz \
  | awk -F'\t' -v total="$total" '
    BEGIN {
      OFS = "\t"
      print "GeneID","Symbol","Description","GeneType","NomenclatureID","Synonyms","OMIM_ID"
    }
    NR > 1 {
      # every 200k lines, update progress on same stderr line
      if (NR % 200000 == 0) {
        printf("\r[%.2f%%] processed", NR/total*100) \
          > "/dev/stderr"
        fflush("/dev/stderr")
      }
      # only Homo sapiens and skip biological-region
      if ($1 == "9606" && $10 != "biological-region") {
        omim = ""
        n = split($6, refs, "|")
        for (i = 1; i <= n; i++) {
          if (refs[i] ~ /^MIM:/) {
            split(refs[i], m, ":")
            omim = (omim ? omim "|" m[2] : m[2])
          }
        }
        print $2, $3, $9, $10, $11, $5, omim
      }
    }
    END {
      # finish the progress line
      printf("\r[100%] processed!\n") > "/dev/stderr"
    }
  ' \
  > ncbi_gene.txt
