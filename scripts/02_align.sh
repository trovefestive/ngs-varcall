#!/usr/bin/env bash
# BWA-MEM alignment, coordinate sort, duplicate marking, index.
set -euo pipefail
source config.sh
mkdir -p "$OUT/bam"
IN1=$OUT/qc/${SAMPLE}_R1.trim.fastq.gz; IN2=$OUT/qc/${SAMPLE}_R2.trim.fastq.gz
[ -s "$IN1" ] || { IN1=$R1; IN2=$R2; echo "[align] no trimmed reads found, using raw FASTQ"; }
RG="@RG\tID:${SAMPLE}\tSM:${SAMPLE}\tPL:ILLUMINA\tLB:${SAMPLE}_lib1"

bwa mem -t "$THREADS" -R "$RG" "$REF" "$IN1" "$IN2" \
  | samtools fixmate -m -u - - \
  | samtools sort -@ "$THREADS" -u -T "$OUT/bam/tmp" - \
  | samtools markdup -@ "$THREADS" -s -f "$OUT/bam/markdup.stats.txt" - "$OUT/bam/${SAMPLE}.md.bam"
samtools index "$OUT/bam/${SAMPLE}.md.bam"
