#!/bin/bash
## List accessions that do not (yet) have complete FASTQ output, so you can resubmit them.
## Works after any download route (loop, xargs, array job, submit_each.sh, ENA).
##
## Usage:
##   bash ~/download-public-data/scripts/find_missing.sh SRR_Acc_List.txt fastq > failed.txt
##   bash ~/download-public-data/scripts/submit_each.sh failed.txt fastq          # or: sbatch --array=1-$(grep -c . failed.txt) ... failed.txt
## Repeat until failed.txt is empty.
##
## An accession counts as missing if it has no .fastq.gz, or if its _1 and _2 files
## fail `gzip -t`, or have different read counts. Reasons go to stderr, accessions to stdout.

LIST=${1:?"give a file of accessions, one per line"}
OUT=${2:-fastq}
missing=0
for acc in $(tr -d '\r' < "$LIST" | grep -v '^\s*$'); do
  files=$(ls "$OUT/${acc}"*.fastq.gz 2>/dev/null || true)
  if [ -z "$files" ]; then
    echo "$acc: no FASTQ" >&2; echo "$acc"; missing=$((missing + 1)); continue
  fi
  bad=""
  for f in $files; do gzip -t "$f" 2>/dev/null || bad="corrupt $(basename "$f")"; done
  if [ -z "$bad" ] && [ -s "$OUT/${acc}_1.fastq.gz" ]; then
    n1=$(( $(gzip -dc "$OUT/${acc}_1.fastq.gz" | wc -l) / 4 ))
    n2=$(( $(gzip -dc "$OUT/${acc}_2.fastq.gz" 2>/dev/null | wc -l) / 4 ))
    [ "$n1" -eq "$n2" ] || bad="_1 has $n1 reads, _2 has $n2"
  fi
  if [ -n "$bad" ]; then echo "$acc: $bad" >&2; echo "$acc"; missing=$((missing + 1)); fi
done
echo "$missing accession(s) missing or incomplete" >&2
