# download-public-data

An in-depth, beginner-friendly guide to downloading raw sequencing data from
GEO / SRA / ENA with the SRA Toolkit (`prefetch`, `vdb-validate`,
`fasterq-dump`), plus scripts for doing it at scale on a laptop, a workstation or any SLURM
cluster.

Read it online: <https://jpflores-13.github.io/download-public-data>

## Where things go

```
~/download-public-data/      ← this repository (the scripts), cloned once
~/public_data/               ← your datasets (on a cluster: in scratch)
└── GSE52778/                ← one folder per dataset; run every command from here
    ├── SRR_Acc_List.txt     ← SRA Run Selector → "Accession List"
    ├── SraRunTable.csv      ← SRA Run Selector → "Metadata"
    ├── runs_to_samples.tsv  ← you make it (run → sample)
    ├── fastq/  merged/  logs/  sra/  tmp/
```

Run Selector saves the two files to your **Downloads** folder: `mv` them into
the dataset folder, or `scp` them up if you work on a cluster. Details:
*Finding the data → Where to put the two files*.

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
cd ~/public_data/GSE52778          # the dataset folder, with SRR_Acc_List.txt in it
mkdir -p logs
sbatch --array=1-$(grep -c . SRR_Acc_List.txt)%4 ~/download-public-data/scripts/download_sra.sh SRR_Acc_List.txt fastq
```

`examples/` holds the accession list and sample table for the airway
dataset (GSE52778) used in the worked example.

## Slides

Two decks (reveal.js) live in `slides/`, a small Quarto project the book builds
into `_book/slides/` after rendering (`post-render` in `_quarto.yml`). Each
chapter gets a **Slides** button from `_filters/slides-button.lua`; which slide
it opens is set under `slide-map:` in `_quarto.yml`. The instructor's live-demo
script is the *Live demo* chapter, with `demo/preflight.sh` and
`demo/make_backup.sh`.

## Build the guide locally

```bash
quarto preview
```

Pushing to `main` renders and deploys the guide to GitHub Pages
(`.github/workflows/quarto-publish.yml`); set **Settings → Pages → Source**
to **GitHub Actions** once.
