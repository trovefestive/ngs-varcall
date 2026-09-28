#!/usr/bin/env bash
# Haplotype-aware benchmark with rtg vcfeval (complements the positional match in evaluate.py).
# Compares PASS calls to the GIAB truth within the evaluation BED (high-confidence ∩ callable),
# so different representations of the same complex variant are reconciled before scoring.
# Requires rtg-tools (conda install -c bioconda rtg-tools).
set -euo pipefail
source config.sh
EVAL=$OUT/vcfeval
EB=$OUT/bamqc/eval.bed
SDF=$DATA/ref/${REGION}.sdf

# Reference SDF restricted to the region (building the full genome SDF takes much longer)
if [ ! -d "$SDF" ]; then
  echo "[vcfeval] building SDF for $REGION"
  samtools faidx "$REF" "$REGION" > "$DATA/ref/${REGION}.fa"
  rtg format -o "$SDF" "$DATA/ref/${REGION}.fa"
  rm -f "$DATA/ref/${REGION}.fa"
fi

rm -rf "$EVAL"
echo "[vcfeval] rtg vcfeval on $REGION within $EB"
rtg vcfeval -t "$SDF" \
  -b "$TRUTH_VCF" -c "$OUT/vcf/${SAMPLE}.${REGION}.vcf.gz" \
  --bed-regions "$EB" \
  --vcf-score-field QUAL --threads "${THREADS}" \
  -o "$EVAL"

# Per-type summary (SNV / INDEL / ALL) with genotype-aware counts
{
  printf "type\tTP\tFP\tFN\tprecision\trecall\tF1\n"
  for t in SNV INDEL ALL; do
    case $t in
      SNV)   f='TYPE="snp"';;
      INDEL) f='TYPE!="snp"';;
      ALL)   f='';;
    esac
    tp=$(bcftools view -H ${f:+-i "$f"} "$EVAL/tp.vcf.gz" | wc -l)
    fp=$(bcftools view -H ${f:+-i "$f"} "$EVAL/fp.vcf.gz" | wc -l)
    fn=$(bcftools view -H ${f:+-i "$f"} "$EVAL/fn.vcf.gz" | wc -l)
    awk -v t=$t -v tp=$tp -v fp=$fp -v fn=$fn 'BEGIN{
      p=(tp+fp)?tp/(tp+fp):0; r=(tp+fn)?tp/(tp+fn):0; f1=(p+r)?2*p*r/(p+r):0;
      printf "%s\t%d\t%d\t%d\t%.4f\t%.4f\t%.4f\n", t,tp,fp,fn,p,r,f1}'
  done
} > "$EVAL/metrics_by_type.tsv"
cat "$EVAL/summary.txt"
echo
cat "$EVAL/metrics_by_type.tsv"
