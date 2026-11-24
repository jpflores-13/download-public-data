#!/bin/bash
#SBATCH -J sra_download
#SBATCH -t 12:00:00
#SBATCH -N 1
#SBATCH -c 6
#SBATCH --mem=8g
#SBATCH -o logs/%x-%A_%a.out
#SBATCH -e logs/%x-%A_%a.err

## Download one SRA run per SLURM array task, convert it to gzipped FASTQ,
## and clean up the intermediate .sra file.
##
## Usage (from the folder where you want the data):
##   mkdir -p logs
##   N=$(grep -c . SRR_Acc_List.txt)
##   sbatch --array=1-${N}%4 scripts/download_sra.sh SRR_Acc_List.txt fastq
##
## Arguments:
##   1. a text file with one run accession (SRR/ERR/DRR) per line
##   2. output folder for FASTQ files (default: fastq)
##
## %4 in --array limits it to 4 downloads at a time; be kind to NCBI and the filesystem.
## Uses the cluster's default partition; add `-p <partition>` to sbatch to choose one.

set -euo pipefail

ACC_LIST=${1:?"give a file of accessions, one per line"}
OUTDIR=${2:-fastq}
THREADS=${SLURM_CPUS_PER_TASK:-6}
TASK=${SLURM_ARRAY_TASK_ID:?"run this with sbatch --array"}

## Pick this task's accession (line number = array index); strip spaces and Windows line ends
ACC=$(sed -n "${TASK}p" "$ACC_LIST" | tr -d '[:space:]')
[ -n "$ACC" ] || { echo "No accession on line $TASK of $ACC_LIST"; exit 1; }
echo "[$(date)] task $TASK -> $ACC"

## Find the tools. If fasterq-dump is already on PATH (e.g. an activated conda
## environment), use it; otherwise try environment modules. Set SRA_MODULE to
## your cluster's module name if it is neither of the defaults.
if ! command -v fasterq-dump >/dev/null 2>&1; then
  for m in ${SRA_MODULE:-} sra-tools sratoolkit; do
    module load "$m" 2>/dev/null && break
  done
fi
command -v fasterq-dump >/dev/null 2>&1 || { echo "fasterq-dump not found: activate conda or set SRA_MODULE"; exit 1; }
command -v pigz >/dev/null 2>&1 || module load pigz 2>/dev/null || true
if command -v pigz >/dev/null; then ZIP="pigz -p $THREADS"; else ZIP="gzip"; fi

SRA_DIR="$OUTDIR/sra"
TMP_DIR="$OUTDIR/tmp/$ACC"
mkdir -p "$OUTDIR" "$SRA_DIR" "$TMP_DIR"

## Skip runs that are already finished (lets you resubmit the whole array safely)
if ls "$OUTDIR/${ACC}"*.fastq.gz >/dev/null 2>&1; then
  echo "$ACC already has FASTQ in $OUTDIR; skipping"
  exit 0
fi

## 1. Download the .sra file (no size limit)
prefetch "$ACC" --max-size u -O "$SRA_DIR"

## 2. Check it is complete and uncorrupted
vdb-validate "$SRA_DIR/$ACC"

## 3. Convert to FASTQ (split-3 by default: _1/_2 for pairs, plain .fastq for unpaired reads)
fasterq-dump "$SRA_DIR/$ACC" \
  --threads "$THREADS" \
  --temp "$TMP_DIR" \
  --outdir "$OUTDIR"

## 4. Compress (fasterq-dump writes uncompressed FASTQ)
$ZIP "$OUTDIR/${ACC}"*.fastq

## 5. Record read counts for later checks, then clean up
for f in "$OUTDIR/${ACC}"*.fastq.gz; do
  echo -e "$(basename "$f")\t$(( $(zcat "$f" | wc -l) / 4 ))" >> "$OUTDIR/read_counts.tsv"
done
rm -rf "$SRA_DIR/$ACC" "$TMP_DIR"

echo "[$(date)] done: $(ls "$OUTDIR/${ACC}"*.fastq.gz | xargs -n1 basename | tr '\n' ' ')"
