#!/usr/bin/env bash
# Alignment QC and the "callable" region mask (depth >= MIN_CALLABLE_DP within REGION).
set -euo pipefail
source config.sh
BAM=$OUT/bam/${SAMPLE}.md.bam
mkdir -p "$OUT/bamqc"
samtools flagstat "$BAM" > "$OUT/bamqc/flagstat.txt"
samtools stats -@ "$THREADS" "$BAM" "$REGION" > "$OUT/bamqc/samtools_stats.txt"

# Per-base depth over REGION (MAPQ/BASEQ filtered, duplicates excluded by default;
# -J counts deletions so homozygous deletions do not punch holes in the callable mask)
samtools depth -a -J -r "$REGION" -Q "$MIN_MAPQ" -q "$MIN_BASEQ" "$BAM" | gzip > "$OUT/bamqc/depth.tsv.gz"

# Callable BED: contiguous bases at >= MIN_CALLABLE_DP
gzip -dc "$OUT/bamqc/depth.tsv.gz" \
  | awk -v m="$MIN_CALLABLE_DP" 'BEGIN{OFS="\t"} $3>=m {print $1,$2-1,$2}' \
  | bedtools merge -i - > "$OUT/bamqc/callable.bed"

# Evaluation BED = GIAB high-confidence regions  ∩  callable  (on REGION only)
awk -v r="$REGION" '$1==r' "$TRUTH_BED" | sort -k1,1 -k2,2n > "$OUT/bamqc/truth_region.bed"
bedtools intersect -a "$OUT/bamqc/truth_region.bed" -b "$OUT/bamqc/callable.bed" \
  | sort -k1,1 -k2,2n | bedtools merge -i - > "$OUT/bamqc/eval.bed"
awk '{s+=$3-$2} END{printf "[bamqc] evaluation territory: %d bp\n", s}' "$OUT/bamqc/eval.bed"
