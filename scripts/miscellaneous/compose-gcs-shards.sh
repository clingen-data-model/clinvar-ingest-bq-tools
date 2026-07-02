#!/bin/bash
BUCKET="gs://clingen-public/upenn/clinvar_scvs_pre_2019_07_01"
SHARDS_DIR="${BUCKET}/temp_shards"
FINAL="${BUCKET}/clinvar_scvs_pre_2019_07_01.json.gz"

# Get all shard files sorted
shards=($(gsutil ls "${SHARDS_DIR}/part_*.json.gz" | sort))
total=${#shards[@]}
echo "Total shards: $total"

if [ "$total" -le 32 ]; then
  gsutil compose "${shards[@]}" "$FINAL"
else
  # Compose in batches of 32, then compose the intermediates
  batch_size=32
  intermediates=()
  batch_num=0

  for ((i=0; i<total; i+=batch_size)); do
    batch=("${shards[@]:i:batch_size}")
    intermediate="${SHARDS_DIR}/_intermediate_${batch_num}.json.gz"
    echo "Composing batch $batch_num (${#batch[@]} files)..."
    gsutil compose "${batch[@]}" "$intermediate"
    intermediates+=("$intermediate")
    ((batch_num++))
  done

  # Final compose of intermediates
  echo "Composing ${#intermediates[@]} intermediates into final file..."
  gsutil compose "${intermediates[@]}" "$FINAL"

  # Clean up intermediates
  echo "Cleaning up intermediates..."
  gsutil rm "${intermediates[@]}"
fi

echo "Done: $FINAL"
