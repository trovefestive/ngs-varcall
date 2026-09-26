#!/usr/bin/env bash
# End-to-end smoke test on simulated data (runs in a few minutes on a laptop).
set -euo pipefail
cd "$(dirname "$0")/.."
D=test/data
python3 test/simulate.py "$D"
bcftools sort -Oz -o "$D/truth.vcf.gz" "$D/truth.vcf" && bcftools index -f -t "$D/truth.vcf.gz"
samtools faidx "$D/ref.fa"; [ -s "$D/ref.fa.bwt" ] || bwa index "$D/ref.fa" 2>/dev/null
export REF=$D/ref.fa R1=$D/reads_R1.fastq.gz R2=$D/reads_R2.fastq.gz \
       TRUTH_VCF=$D/truth.vcf.gz TRUTH_BED=$D/truth.bed OUT=test/results THREADS=${THREADS:-4}
if command -v fastp >/dev/null; then SKIP_FASTP=0; else SKIP_FASTP=1; echo "[test] fastp not found, aligning raw reads"; fi
SKIP_DOWNLOAD=1 SKIP_FASTP=$SKIP_FASTP bash scripts/run_all.sh
