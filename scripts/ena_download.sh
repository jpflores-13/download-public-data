#!/bin/bash
## Download gzipped FASTQ directly from ENA (no SRA Toolkit needed) and check MD5s.
##
## Usage:
##   bash scripts/ena_download.sh PRJNA229998 fastq      # a whole project
##   bash scripts/ena_download.sh SRR1039508 fastq       # one run
## Accepts project (PRJNA/PRJEB, SRP), sample (SAMN, SRS), experiment (SRX) or run (SRR/ERR/DRR) accessions.

set -euo pipefail

ACC=${1:?"give an accession"}
OUT=${2:-fastq}
mkdir -p "$OUT"

API="https://www.ebi.ac.uk/ena/portal/api/filereport"
FIELDS="run_accession,sample_accession,experiment_accession,library_layout,read_count,fastq_ftp,fastq_md5,fastq_bytes"

## 1. Ask ENA which files exist (saves a table you can keep as metadata)
curl -s "${API}?accession=${ACC}&result=read_run&fields=${FIELDS}&format=tsv" > "$OUT/${ACC}_filereport.tsv"
n=$(( $(wc -l < "$OUT/${ACC}_filereport.tsv") - 1 ))
echo "ENA lists $n run(s) for $ACC (table: $OUT/${ACC}_filereport.tsv)"
[ "$n" -gt 0 ] || { echo "Nothing found; check the accession"; exit 1; }

## 2. Download each file and record its expected MD5
: > "$OUT/${ACC}.md5"
tail -n +2 "$OUT/${ACC}_filereport.tsv" | while IFS=$'\t' read -r run sample exp layout reads ftp md5 bytes; do
  IFS=';' read -ra urls <<< "$ftp"
  IFS=';' read -ra sums <<< "$md5"
  for i in "${!urls[@]}"; do
    f=$(basename "${urls[$i]}")
    echo "${sums[$i]}  $f" >> "$OUT/${ACC}.md5"
    if [ -s "$OUT/$f" ]; then echo "have $f"; continue; fi
    echo "downloading $f"
    wget -q -c -O "$OUT/$f" "https://${urls[$i]}"
  done
done

## 3. Verify
( cd "$OUT" && md5sum -c "${ACC}.md5" )
