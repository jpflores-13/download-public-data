#!/bin/bash
## Submit one SLURM job per accession (instead of an array job).
## Each job: prefetch -> vdb-validate -> convert to gzipped FASTQ -> delete .sra.
##
## Run from the dataset folder (e.g. ~/public_data/GSE52778) that contains
## SRR_Acc_List.txt; this repository is assumed cloned to ~/download-public-data.
## Usage:
##   bash ~/download-public-data/scripts/submit_each.sh SRR_Acc_List.txt [outdir]
##   bash ~/download-public-data/scripts/submit_each.sh failed.txt      # resubmit only what failed (see find_missing.sh)
##
## Options, set as environment variables:
##   CONVERTER=fasterq (default) | parallel   use fasterq-dump + pigz, or parallel-fastq-dump --gzip
##   THREADS=4                                CPUs per job
##   PARTITION=<name>                         SLURM partition (default: the cluster's default)
##   SRA_MODULE=<name>                        module to load if fasterq-dump is not already on PATH
## Example:
##   CONVERTER=parallel PARTITION=general bash ~/download-public-data/scripts/submit_each.sh SRR_Acc_List.txt fastq

set -euo pipefail
LIST=${1:?"give a file of accessions, one per line"}
OUT=${2:-fastq}
CONVERTER=${CONVERTER:-fasterq}
THREADS=${THREADS:-4}
PART_LINE=""; [ -n "${PARTITION:-}" ] && PART_LINE="#SBATCH -p ${PARTITION}"
mkdir -p logs "$OUT/sra" "$OUT/tmp"

n=0
for acc in $(tr -d '\r' < "$LIST" | grep -v '^\s*$'); do
  if ls "$OUT/${acc}"*.fastq.gz >/dev/null 2>&1; then echo "$acc: already done, skipping"; continue; fi
  jid=$(sbatch --parsable <<EOS
#!/bin/bash
#SBATCH -J dl_${acc}
#SBATCH -N 1
#SBATCH -c ${THREADS}
#SBATCH --mem=8g
#SBATCH -t 24:00:00
#SBATCH -o logs/dl_${acc}_%j.out
#SBATCH -e logs/dl_${acc}_%j.err
${PART_LINE}
set -euo pipefail
if ! command -v prefetch >/dev/null 2>&1; then
  for m in ${SRA_MODULE:-} sra-tools sratoolkit; do module load "\$m" 2>/dev/null && break; done
fi
prefetch ${acc} --max-size u -O ${OUT}/sra
vdb-validate ${OUT}/sra/${acc}
if [ "${CONVERTER}" = "parallel" ]; then
  command -v parallel-fastq-dump >/dev/null 2>&1 || module load parallel-fastq-dump
  parallel-fastq-dump --sra-id ${OUT}/sra/${acc} --threads ${THREADS} --outdir ${OUT} \\
    --tmpdir ${OUT}/tmp --split-3 --skip-technical --gzip
else
  fasterq-dump ${OUT}/sra/${acc} --threads ${THREADS} --temp ${OUT}/tmp/${acc} --outdir ${OUT}
  if command -v pigz >/dev/null 2>&1; then pigz -p ${THREADS} ${OUT}/${acc}*.fastq; else gzip ${OUT}/${acc}*.fastq; fi
fi
rm -rf ${OUT}/sra/${acc} ${OUT}/tmp/${acc}
echo "done: ${acc}"
EOS
)
  echo "$acc: submitted job $jid"
  n=$((n + 1))
done
echo "Submitted $n job(s). Check progress with: squeue -u \$USER"
echo "When they finish, list anything missing with: bash ~/download-public-data/scripts/find_missing.sh $LIST $OUT > failed.txt"
