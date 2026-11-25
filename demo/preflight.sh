#!/bin/bash
## Pre-flight check for the live download demo. Run it the day before AND
## 15 minutes before class, in the terminal you'll present from:
##   bash demo/preflight.sh
## Every line should say OK. Anything marked FIX needs attention before class.

ok()  { printf "  \033[32mOK\033[0m   %s\n" "$1"; }
bad() { printf "  \033[31mFIX\033[0m  %s\n" "$1"; FAIL=1; }
FAIL=0
echo "== Tools"
for t in prefetch vdb-validate fasterq-dump fastq-dump curl; do
  command -v $t >/dev/null 2>&1 && ok "$t found" || bad "$t not found (conda activate sra, or module load)"
done
command -v pigz >/dev/null 2>&1 && ok "pigz found" || { command -v gzip >/dev/null && ok "pigz missing, will use gzip (slower)"; }
v=$(fasterq-dump --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
[ -n "$v" ] && { [ "${v%%.*}" -ge 3 ] && ok "SRA Toolkit version $v" || bad "SRA Toolkit $v is old; use 3.x"; }

echo "== Network"
curl -s -o /dev/null -m 15 -w "%{http_code}" https://www.ncbi.nlm.nih.gov/ | grep -q 200 && ok "NCBI reachable" || bad "NCBI not reachable"
warn() { printf "  \033[33mWARN\033[0m %s\n" "$1"; }
curl -s -m 60 "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=SRR390728&result=read_run&fields=read_count&format=tsv" | grep -q 7178576 \
  && ok "ENA API reachable" || warn "ENA API slow or down right now (only needed for the ENA part; use the backup table)"

echo "== Disk (need ~5 GB free here: $(pwd))"
free_gb=$(df -Pk . | awk 'NR==2 {print int($4/1024/1024)}')
[ "$free_gb" -ge 5 ] && ok "${free_gb} GB free" || bad "only ${free_gb} GB free"

echo "== Toolkit can fetch data (2 reads of SRR390728)"
out=$(timeout 120 fastq-dump --stdout -X 2 SRR390728 2>/dev/null || fastq-dump --stdout -X 2 SRR390728 2>/dev/null)
[ "$(echo "$out" | grep -c '^@SRR390728')" -eq 2 ] && ok "fastq-dump test passed" || bad "fastq-dump test failed (run vdb-config -i once; check network)"

echo "== Backup for plan B"
[ -s "$HOME/demo_backup/fastq/SRR390728_1.fastq.gz" ] && ok "backup present in ~/demo_backup" || bad "no backup yet: run bash demo/make_backup.sh"

echo
[ $FAIL -eq 0 ] && echo "All set. Break a leg!" || echo "Fix the lines marked FIX, then run this again."
