#!/usr/bin/env bash
# Germline SNV/indel calling with bcftools, left-normalization, soft filtering.
# One mpileup per chromosome in parallel, then concatenated in REGION order.
set -euo pipefail
source config.sh
BAM=$OUT/bam/${SAMPLE}.md.bam
V=$OUT/vcf
mkdir -p "$V/tmp"
call_chrom() {
  bcftools mpileup -Ou -f "$REF" -r "$1" -q "$MIN_MAPQ" -Q "$MIN_BASEQ" \
      -a FORMAT/AD,FORMAT/DP --max-depth 1000 "$BAM" 2> "$V/tmp/$1.log" \
    | bcftools call -Ou -mv \
    | bcftools norm -Ob -f "$REF" -m -both -o "$V/tmp/$1.bcf" 2>> "$V/tmp/$1.log"
}
export -f call_chrom; export BAM V REF MIN_MAPQ MIN_BASEQ
printf '%s\n' $CHROMS | xargs -P "$THREADS" -I{} bash -c 'call_chrom {}'

bcftools concat -Ou $(for c in $CHROMS; do echo "$V/tmp/$c.bcf"; done) \
  | bcftools filter -Ou -s LowQual -e "QUAL<${FILTER_QUAL} || FORMAT/DP<${FILTER_DP}" \
  | bcftools filter -Oz -m+ -s IndelLowAF \
      -e "TYPE=\"indel\" && FMT/AD[0:0]+FMT/AD[0:1]>0 && FMT/AD[0:1]/(FMT/AD[0:0]+FMT/AD[0:1]) < ${FILTER_INDEL_AF}" \
      -o "$V/${SAMPLE}.${REGION}.vcf.gz"
rm -rf "$V/tmp"
bcftools index -t "$V/${SAMPLE}.${REGION}.vcf.gz"
bcftools stats -F "$REF" "$V/${SAMPLE}.${REGION}.vcf.gz" > "$V/bcftools_stats.txt"
