# Germline variant calling and QC on GIAB NA12878 (exome)

A small, reproducible short-read variant-calling workflow benchmarked against the
Genome in a Bottle HG001 (NA12878) v4.2.1 truth set. It covers the steps a sequencing
lab uses to decide whether a run's calls can be trusted: read QC, alignment QC,
coverage and a callable-region mask, variant calling, and accuracy against a known truth set,
with a short list of false positives and false negatives to review in IGV.

**Status:** pipeline tested end to end on simulated data (`test/`) and run on Rivanna against GIAB HG001
chr20 (one exome lane, then all four lanes merged) and on all autosomes from the four-lane BAM.
Results and site review are below; the full reports and small outputs for each run are kept in `runs/`.

## Workflow

| step | script | tools | output |
|---|---|---|---|
| 0 | `00_download.sh` | curl, samtools, bwa | GRCh38 no-alt reference + BWA index, NIST7035 exome FASTQ, GIAB truth VCF/BED |
| 1 | `01_read_qc.sh` | fastp | trimmed reads, Q30/GC/adapter report |
| 2 | `02_align.sh` | bwa mem, samtools fixmate/sort/markdup | duplicate-marked BAM |
| 3 | `03_bam_qc.sh` | samtools flagstat/stats/depth, bedtools | mapping/duplicate/insert-size QC, depth histogram, callable BED, evaluation BED |
| 4 | `04_call.sh` | bcftools mpileup/call/norm/filter | normalized, soft-filtered VCF (`LowQual`: QUAL<20 or DP<10; `IndelLowAF`: indel alt fraction < 0.2) |
| 5 | `05_evaluate.sh`, `evaluate.py` | bcftools, pysam | precision / recall / F1 for SNVs and indels, genotype concordance, per-site table |
| 6 | `06_report.py` | pandas, matplotlib | `results/report.md` with figures |

`REGION` in `config.sh` sets the chromosomes: chr20 by default, or `REGION=autosomes` for chr1-22
(the GIAB v4.2.1 truth covers autosomes only). Steps 3 and 4 run one chromosome per process.
The evaluation territory is GIAB high-confidence regions on those chromosomes intersected with bases
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

# 3) optional: all four Garvan lanes merged (after step 2; writes results_4lane/)
sbatch slurm/run_rivanna_4lane.slurm

# 4) optional: whole exome, chr1-22, reusing the four-lane BAM (after step 3; writes results_exome/)
sbatch slurm/run_rivanna_exome.slurm
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
  indel benchmark, `scripts/07_vcfeval.sh` runs `rtg vcfeval` (haplotype-aware, genotype-checked)
  on the same BED and writes `results/vcfeval/`. It is not part of `run_all.sh`; run it after.

## Results (GIAB HG001, chr20)

Two runs: NIST7035 lane 1 alone (job 20562709, `runs/rivanna_chr20_20562709/`) and all four
Garvan lanes merged, NIST7035 L001+L002 and NIST7086 L001+L002 (job 20570014,
`runs/rivanna_chr20_4lane_20570014/`).

| metric | 1 lane | 4 lanes |
|---|---:|---:|
| reads after fastp (R1+R2) | 37.8M | 157.6M |
| Q30 bases, after fastp | 94.0% | 93.9% |
| mapped / properly paired | 100.0% / 99.46% | 100.0% / 99.43% |
| duplicate rate | 6.1% | 14.1% |
| median depth over callable bases (≥10x, chr20) | 27x | 66x |
| callable bases on chr20 (≥10x) | 1.85 Mb | 2.77 Mb |
| evaluation territory (high-confidence ∩ callable) | 1.74 Mb | 2.58 Mb |

Accuracy from `rtg vcfeval` (haplotype-aware, genotype must match, PASS calls). Both call sets are
scored on the **single-lane evaluation BED**, which lies entirely inside the four-lane one, so the
columns are comparable:

| run | type | TP | FP | FN | precision | recall | F1 |
|---|---|---:|---:|---:|---:|---:|---:|
| 1 lane | SNV | 1377 | 7 | 77 | 0.9949 | 0.9470 | 0.9704 |
| 4 lanes | SNV | 1442 | 10 | 12 | 0.9931 | 0.9917 | 0.9924 |
| 1 lane | INDEL | 108 | 22 | 31 | 0.8308 | 0.7770 | 0.8030 |
| 4 lanes | INDEL | 115 | 41 | 24 | 0.7372 | 0.8273 | 0.7797 |

Ignoring genotype (`--squash-ploidy`), indel F1 is 0.885 at one lane and 0.875 at four. On its own
full evaluation region, the four-lane run scores SNV F1 0.979 and indel F1 0.731.

What the numbers and the IGV review show:

- **SNVs improve cleanly with depth.** Recall goes from 0.947 to 0.992 on the same region.
- **Paralog mis-mapping, not depth.** Six het SNV false negatives at chr20:5474151-5474467 persist at
  both depths (mean 43x at one lane, 172/184 reads MAPQ ≥ 20, 0-1 alt reads per site). Every read in
  the window has an XA tag pointing to a segmental duplication near chr20:5.50 Mb, so the alt-haplotype
  reads land on the paralog, and the het FP SNV at chr20:5501412 is the same signal on the other copy.
- **Representation, not error.** The hom-alt FP SNVs at chr20:1915304-1915306 and the FN indels at
  1915303-1915304 are one complex variant written two ways. The positional script in `05_evaluate.sh`
  counts them as FP + FN; vcfeval scores them as TP.
- **Indel false positives grow with depth.** With more reads, bcftools emits more low-allele-fraction
  1-3 bp indels in homopolymers and short tandem repeats: of the 74 genotype-aware FP indels in the
  four-lane run, 39 have alt fraction below 0.35 and 17 below 0.2. Some other indel FPs are the right
  allele with the wrong genotype (14 of 41 on the common region at four lanes, 11 at one lane), or
  multi-allelic sites where only one of two alt alleles matches the truth (e.g. 25452811).

The chr20 runs above predate the `IndelLowAF` filter; their VCFs carry only `LowQual`.

### Whole exome, chr1-22 (job 20625597, `runs/rivanna_exome_20625597/`)

Four-lane BAM, not realigned. 107.3 Mb at ≥10x (median 63x), 101.3 Mb evaluation territory,
106,841 truth variants. vcfeval, genotype-aware, PASS calls with `IndelLowAF`:

| type | TP | FP | FN | precision | recall | F1 |
|---|---:|---:|---:|---:|---:|---:|
| SNV | 92317 | 1741 | 3285 | 0.9815 | 0.9656 | 0.9735 |
| INDEL | 8376 | 2829 | 2632 | 0.7475 | 0.7609 | 0.7542 |
| ALL | 100693 | 4570 | 5917 | 0.9566 | 0.9445 | 0.9505 |

- **Indel filter, tuned on chr20 and checked on the other chromosomes.** Sweeping allele-fraction and
  `IDV` cutoffs on the chr20 four-lane calls, the best genotype-aware indel F1 came from soft-filtering
  indels with alt fraction < 0.2 (0.731 to 0.746); `IDV` added nothing. On the 21 held-out autosomes
  the same filter raises indel precision by 3.0 points for 1.5 points of recall (F1 0.746 to 0.754;
  allele-only 0.833 to 0.842). The gain is real but small: the remaining indel errors are wrong-allele
  calls in repeats and right-allele/wrong-genotype calls, many at sites bcftools calls as two different
  indel alleles (`1/2`). Those need a haplotype-aware caller rather than a filter.
- **Mapping limits recur genome-wide.** 139 of the 163 SNV false negatives on chr6 sit in the MHC
  (chr6:28.5-33.5 Mb), the largest cluster in the exome, the same kind of short-read mapping limit as
  the chr20:5.47 Mb paralog cluster.
- Without the new filter, the chr20 subset of the exome run gives exactly the chr20-only four-lane counts, so the
  per-chromosome rewrite of steps 3-4 reproduces the earlier results.

## Data sources

- GIAB HG001 v4.2.1 benchmark (Wagner et al., *Nat Biotechnol* 2022) — ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/NA12878_HG001/NISTv4.2.1/GRCh38/
- Garvan NA12878 HiSeq exome (NIST7035) — ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/data/NA12878/Garvan_NA12878_HG001_HiSeq_Exome/
- GRCh38 no-alt analysis set — NCBI GCA_000001405.15
