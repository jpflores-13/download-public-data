#!/bin/bash
## Run the whole demo once, ahead of time, into ~/demo_backup.
## It is your rehearsal (note how long each step takes) and your plan B:
## if the network fails during class, copy from the backup instead.
##   bash demo/make_backup.sh
set -euo pipefail
B=$HOME/demo_backup
mkdir -p $B/sra $B/tmp $B/fastq && cd $B
t() { local s=$(date +%s); "$@"; echo "   (took $(( $(date +%s) - s )) s)"; }

echo "== 1. Metadata from ENA";      t curl -s "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=SRR390728&result=read_run&fields=run_accession,read_count,base_count,library_layout,instrument_model,fastq_ftp,fastq_md5&format=tsv" -o SRR390728_ena.tsv
echo "== 2. prefetch";                t prefetch SRR390728 --max-size u -O sra
echo "== 3. vdb-validate";            t vdb-validate sra/SRR390728
echo "== 4. fasterq-dump";            t fasterq-dump sra/SRR390728 --threads 4 --temp tmp --outdir fastq
echo "== 5. compress";                if command -v pigz >/dev/null; then t pigz -p 4 fastq/SRR390728*.fastq; else t gzip fastq/SRR390728*.fastq; fi
echo "== 6. read counts"
for f in fastq/*.fastq.gz; do echo "   $(basename $f): $(( $(gzip -dc $f | wc -l) / 4 ))"; done
echo "   archive says: $(cut -f2 SRR390728_ena.tsv | tail -1) spots"
du -sh sra fastq
echo "Backup ready in $B (keep sra/ too: plan B can start from any step)."
