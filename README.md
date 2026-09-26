# Germline variant calling and QC on GIAB NA12878 (chr20 exome)

A small, reproducible short-read variant-calling workflow benchmarked against the
Genome in a Bottle HG001 (NA12878) v4.2.1 truth set. It covers the steps a sequencing
lab uses to decide whether a run's calls can be trusted: read QC, alignment QC,
coverage and a callable-region mask, variant calling, and accuracy against a known truth set,
with a short list of false positives and false negatives to review in IGV.

**Status:** pipeline tested end to end on simulated data (`test/`). GIAB results: _pending, fill in below after the first real run._

## Workflow

| step | script | tools | output |
|---|---|---|---|
| 0 | `00_download.sh` | curl, samtools, bwa | GRCh38 no-alt reference + BWA index, NIST7035 exome FASTQ, GIAB truth VCF/BED |
| 1 | `01_read_qc.sh` | fastp | trimmed reads, Q30/GC/adapter report |
| 2 | `02_align.sh` | bwa mem, samtools fixmate/sort/markdup | duplicate-marked BAM |
| 3 | `03_bam_qc.sh` | samtools flagstat/stats/depth, bedtools | mapping/duplicate/insert-size QC, per-base depth, callable BED, evaluation BED |
| 4 | `04_call.sh` | bcftools mpileup/call/norm/filter | normalized, soft-filtered VCF (`LowQual`: QUAL<20 or DP<10) |
| 5 | `05_evaluate.sh`, `evaluate.py` | bcftools, pysam | precision / recall / F1 for SNVs and indels, genotype concordance, per-site table |
| 6 | `06_report.py` | pandas, matplotlib | `results/report.md` with figures |

The evaluation territory is GIAB high-confidence regions on chr20 intersected with bases
covered at ≥10x in this sample, so exome off-target regions are not counted as misses.

## Run it

```bash
mamba env create -f environment.yml && conda activate ngs-varcall

# 1) smoke test on simulated data (a few minutes, no downloads)
bash test/run_test.sh

# 2) real data: interactively ...
bash scripts/run_all.sh
# ... or on UVA HPC (edit the allocation first)
sbatch slurm/run_rivanna.slurm
```

Settings (threads, thresholds, paths, URLs) are in `config.sh`. If your cluster already
has a BWA index for GRCh38 no-alt, point `REF` at it to skip the ~1 h indexing step.

## Design notes

- **Normalize before comparing.** Both call and truth VCFs are left-aligned and split
  (`bcftools norm -m -both`) before any region filtering, so an indel that shifts left in a
  repeat is judged at its final position. (The smoke test caught this: filtering the truth set
  before normalizing dropped a left-shifted deletion and turned the matching call into a false positive.)
- **Deletions count toward depth.** `samtools depth -J` keeps homozygous deletions from
  punching zero-depth holes in the callable mask.
- **Soft filters.** Filtered calls stay in the VCF with a `LowQual` flag, so `sites.tsv` can
  separate "filtered true variant" (`FN_filtered`) from "missed entirely" (`FN`), which is the
  information needed to tune thresholds.
- **Matching is allele-level**, on (chrom, pos, ref, alt). That is enough for SNVs; for a formal
  indel benchmark, run `hap.py` or `rtg vcfeval` on `results/eval/*.vcf.gz` with the same BED.

## Results (GIAB HG001, chr20, NIST7035 lane 1)

_Fill in from `results/report.md` after the run: mapped %, duplicate %, median depth,
callable territory, and the SNV/indel precision/recall/F1 table, plus two or three
false-positive or false-negative sites reviewed in IGV with a short note on the cause
(e.g. low MAPQ, homopolymer, strand bias, low allele fraction)._

## Data sources

- GIAB HG001 v4.2.1 benchmark (Wagner et al., *Nat Biotechnol* 2022) — ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/NA12878_HG001/NISTv4.2.1/GRCh38/
- Garvan NA12878 HiSeq exome (NIST7035) — ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/data/NA12878/Garvan_NA12878_HG001_HiSeq_Exome/
- GRCh38 no-alt analysis set — NCBI GCA_000001405.15
