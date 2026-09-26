#!/usr/bin/env bash
# Restrict truth and calls to the evaluation BED, normalize both, then score.
set -euo pipefail
source config.sh
mkdir -p "$OUT/eval"
EB=$OUT/bamqc/eval.bed
# Normalize first, then restrict, so left-shifted indels are judged at their final position
bcftools norm -Ou -f "$REF" -m -both -r "$REGION" "$TRUTH_VCF" \
  | bcftools view -Oz -T "$EB" -o "$OUT/eval/truth.eval.vcf.gz"
bcftools view -Oz -T "$EB" -f PASS "$OUT/vcf/${SAMPLE}.${REGION}.vcf.gz" -o "$OUT/eval/calls.pass.eval.vcf.gz"
bcftools view -Oz -T "$EB" "$OUT/vcf/${SAMPLE}.${REGION}.vcf.gz" -o "$OUT/eval/calls.all.eval.vcf.gz"
for f in "$OUT"/eval/*.vcf.gz; do bcftools index -f -t "$f"; done
python3 scripts/evaluate.py --truth "$OUT/eval/truth.eval.vcf.gz" \
    --calls "$OUT/eval/calls.pass.eval.vcf.gz" --all-calls "$OUT/eval/calls.all.eval.vcf.gz" \
    --out "$OUT/eval"
