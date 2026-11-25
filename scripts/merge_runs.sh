#!/bin/bash
## Combine the runs (SRR...) that belong to one sample into one pair of FASTQ
## files named like Illumina output: <sample>_R1_001.fastq.gz, <sample>_R2_001.fastq.gz
##
## Usage:
##   bash ~/download-public-data/scripts/merge_runs.sh runs_to_samples.tsv fastq merged
##
## runs_to_samples.tsv: tab-separated, with a header line, columns: run  sample
##   run          sample
##   SRR1039508   N61311_untrt
##   SRR1039509   N61311_dex
## Several rows may share a sample name; their runs are concatenated in file order.
##
## Concatenated .gz files are valid .gz files, so nothing is decompressed.

set -euo pipefail

MAP=${1:?"runs_to_samples.tsv"}
IN=${2:-fastq}
OUT=${3:-merged}
mkdir -p "$OUT"

## list of sample names, in first-seen order
samples=$(tail -n +2 "$MAP" | tr -d '\r' | awk -F'\t' 'NF >= 2 && !seen[$2]++ {print $2}')

for s in $samples; do
  runs=$(tail -n +2 "$MAP" | tr -d '\r' | awk -F'\t' -v s="$s" '$2 == s {print $1}')
  r1=(); r2=(); se=()
  for r in $runs; do
    if [ -s "$IN/${r}_1.fastq.gz" ]; then
      r1+=("$IN/${r}_1.fastq.gz"); r2+=("$IN/${r}_2.fastq.gz")
    elif [ -s "$IN/${r}.fastq.gz" ]; then
      se+=("$IN/${r}.fastq.gz")
    else
      echo "WARNING: no FASTQ found for run $r (sample $s)" >&2
    fi
  done
  if [ ${#r1[@]} -gt 0 ]; then
    cat "${r1[@]}" > "$OUT/${s}_R1_001.fastq.gz"
    cat "${r2[@]}" > "$OUT/${s}_R2_001.fastq.gz"
    echo "$s: paired, ${#r1[@]} run(s)"
  fi
  if [ ${#se[@]} -gt 0 ]; then
    if [ ${#r1[@]} -gt 0 ]; then
      echo "  note: $s also has unpaired-read files; they are not included in R1/R2" >&2
    else
      cat "${se[@]}" > "$OUT/${s}_R1_001.fastq.gz"
      echo "$s: single-end, ${#se[@]} run(s)"
    fi
  fi
done
