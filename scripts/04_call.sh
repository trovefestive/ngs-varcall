#!/usr/bin/env bash
# Germline SNV/indel calling with bcftools, left-normalization, soft filtering.
set -euo pipefail
source config.sh
BAM=$OUT/bam/${SAMPLE}.md.bam
mkdir -p "$OUT/vcf"
bcftools mpileup -Ou -f "$REF" -r "$REGION" -q "$MIN_MAPQ" -Q "$MIN_BASEQ" \
    -a FORMAT/AD,FORMAT/DP --max-depth 1000 "$BAM" \
  | bcftools call -Ou -mv \
  | bcftools norm -Ou -f "$REF" -m -both \
  | bcftools filter -Oz -s LowQual -e "QUAL<${FILTER_QUAL} || FORMAT/DP<${FILTER_DP}" \
      -o "$OUT/vcf/${SAMPLE}.${REGION}.vcf.gz"
bcftools index -t "$OUT/vcf/${SAMPLE}.${REGION}.vcf.gz"
bcftools stats -F "$REF" "$OUT/vcf/${SAMPLE}.${REGION}.vcf.gz" > "$OUT/vcf/bcftools_stats.txt"
