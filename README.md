# download-public-data

An in-depth, beginner-friendly guide to downloading raw sequencing data from
GEO / SRA / ENA with the SRA Toolkit (`prefetch`, `vdb-validate`,
`fasterq-dump`), plus scripts for doing it at scale on a laptop, a workstation or any SLURM
cluster.

Read it online: <https://jpflores-13.github.io/download-public-data>

## Quick start

```bash
prefetch SRR1039508 --max-size u
vdb-validate SRR1039508
fasterq-dump SRR1039508 --threads 6 --temp /path/to/scratch
pigz -p 6 SRR1039508*.fastq
```

## Scripts

| Script | Does |
|---|---|
| `scripts/download_sra.sh` | SLURM array job: prefetch → validate → fasterq-dump → compress, one run per task |
| `scripts/submit_each.sh` | One SLURM job per run (fasterq-dump or parallel-fastq-dump) |
| `scripts/find_missing.sh` | List runs with missing/corrupt/mismatched FASTQ, to resubmit |
| `scripts/merge_runs.sh` | Join runs of the same sample; rename to `<sample>_R1_001.fastq.gz` |
| `scripts/ena_download.sh` | Download `.fastq.gz` straight from ENA and check MD5s |

```bash
mkdir -p logs
sbatch --array=1-$(grep -c . SRR_Acc_List.txt)%4 scripts/download_sra.sh SRR_Acc_List.txt fastq
```

`examples/` holds the accession list and sample table for the airway
dataset (GSE52778) used in the worked example.

## Build the guide locally

```bash
quarto preview
```

Pushing to `main` renders and deploys the guide to GitHub Pages
(`.github/workflows/quarto-publish.yml`); set **Settings → Pages → Source**
to **GitHub Actions** once.
