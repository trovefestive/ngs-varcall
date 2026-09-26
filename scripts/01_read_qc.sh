#!/usr/bin/env bash
# Adapter/quality trimming and read-level QC with fastp.
set -euo pipefail
source config.sh
mkdir -p "$OUT/qc"
fastp -i "$R1" -I "$R2" \
      -o "$OUT/qc/${SAMPLE}_R1.trim.fastq.gz" -O "$OUT/qc/${SAMPLE}_R2.trim.fastq.gz" \
      --detect_adapter_for_pe --qualified_quality_phred 20 --length_required 50 \
      --thread "$THREADS" \
      --json "$OUT/qc/fastp.json" --html "$OUT/qc/fastp.html"
